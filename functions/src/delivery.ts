import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";
import { defineString } from "firebase-functions/params";
import axios from "axios";
 
const db = getFirestore();
 
// ─────────────────────────────────────────────────────────────────
// Setup:
//   firebase functions:secrets:set GOSEND_CLIENT_ID
//   firebase functions:secrets:set GOSEND_CLIENT_SECRET
//   firebase functions:secrets:set GOSEND_MERCHANT_ID
//   firebase functions:secrets:set GRAB_CLIENT_ID
//   firebase functions:secrets:set GRAB_CLIENT_SECRET
//   firebase functions:secrets:set GRAB_MERCHANT_ID
// ─────────────────────────────────────────────────────────────────
const GOSEND_CLIENT_ID      = defineString("GOSEND_CLIENT_ID");
const GOSEND_CLIENT_SECRET  = defineString("GOSEND_CLIENT_SECRET");
const GOSEND_MERCHANT_ID    = defineString("GOSEND_MERCHANT_ID");
const GOSEND_IS_PRODUCTION  = defineString("GOSEND_IS_PRODUCTION", { default: "false" });
 
const GRAB_CLIENT_ID        = defineString("GRAB_CLIENT_ID");
const GRAB_CLIENT_SECRET    = defineString("GRAB_CLIENT_SECRET");
const GRAB_MERCHANT_ID      = defineString("GRAB_MERCHANT_ID");
const GRAB_IS_PRODUCTION    = defineString("GRAB_IS_PRODUCTION", { default: "false" });
 
// ─── Config helpers ───────────────────────────────────────────────
const goSendBase = () =>
  GOSEND_IS_PRODUCTION.value() === "true"
    ? "https://api.gojek.com"
    : "https://api-sandbox.gojek.com";
 
const grabBase = () =>
  GRAB_IS_PRODUCTION.value() === "true"
    ? "https://api.grab.com"
    : "https://partner-api.grab.com";
 
// ─── Token helpers ────────────────────────────────────────────────
async function getGoSendToken(): Promise<string> {
  const r = await axios.post(
    `${goSendBase()}/auth/oauth2/token`,
    new URLSearchParams({
      grant_type: "client_credentials",
      client_id: GOSEND_CLIENT_ID.value(),
      client_secret: GOSEND_CLIENT_SECRET.value(),
      scope: "gojek.driver.order.create",
    }),
    { headers: { "Content-Type": "application/x-www-form-urlencoded" } }
  );
  return r.data.access_token as string;
}
 
async function getGrabToken(): Promise<string> {
  const r = await axios.post(
    `${grabBase()}/grabid/v1/oauth2/token`,
    {
      client_id: GRAB_CLIENT_ID.value(),
      client_secret: GRAB_CLIENT_SECRET.value(),
      grant_type: "client_credentials",
      scope: "grab_express.partner_deliveries",
    },
    { headers: { "Content-Type": "application/json" } }
  );
  return r.data.access_token as string;
}
 
// ─── Types ────────────────────────────────────────────────────────
interface Coordinate { latitude: number; longitude: number; address: string; }
 
interface ShippingRate {
  provider: "gosend" | "grab";
  serviceType: string;
  serviceName: string;
  price: number;
  currency: string;
  estimatedDelivery: string;
  available: boolean;
  errorMessage?: string;
}
 
// ─────────────────────────────────────────────────────────────────
// FUNCTION 1: Hitung ongkir GoSend + Grab
// ─────────────────────────────────────────────────────────────────
export const getShippingRates = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login diperlukan.");
    }
 
    const { origin, destination, weightKg = 1 } = request.data as {
      origin: Coordinate;
      destination: Coordinate;
      weightKg?: number;
    };
 
    if (!origin?.latitude || !destination?.latitude) {
      throw new HttpsError("invalid-argument", "origin dan destination wajib diisi.");
    }
 
    const [goResult, grabResult] = await Promise.allSettled([
      fetchGoSendRates(origin, destination, weightKg),
      fetchGrabRates(origin, destination, weightKg),
    ]);
 
    const rates: ShippingRate[] = [];
 
    if (goResult.status === "fulfilled") {
      rates.push(...goResult.value);
    } else {
      logger.warn("GoSend rate gagal:", goResult.reason);
      rates.push({ provider: "gosend", serviceType: "instant", serviceName: "GoSend Instant", price: 0, currency: "IDR", estimatedDelivery: "-", available: false, errorMessage: "Layanan GoSend tidak tersedia." });
    }
 
    if (grabResult.status === "fulfilled") {
      rates.push(...grabResult.value);
    } else {
      logger.warn("Grab rate gagal:", grabResult.reason);
      rates.push({ provider: "grab", serviceType: "instant", serviceName: "GrabExpress", price: 0, currency: "IDR", estimatedDelivery: "-", available: false, errorMessage: "Layanan GrabExpress tidak tersedia." });
    }
 
    return { rates };
  }
);
 
async function fetchGoSendRates(origin: Coordinate, destination: Coordinate, weightKg: number): Promise<ShippingRate[]> {
  const token = await getGoSendToken();
  const merchantId = GOSEND_MERCHANT_ID.value();
  const r = await axios.post(
    `${goSendBase()}/v1/merchant/orders/calculate-price`,
    { merchant_id: merchantId, origin: { lat: origin.latitude, lng: origin.longitude, address: origin.address }, destination: { lat: destination.latitude, lng: destination.longitude, address: destination.address }, item: { weight: weightKg, quantity: 1 } },
    { headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json", "X-Merchant-ID": merchantId } }
  );
  return (r.data.services ?? []).map((s: any): ShippingRate => ({
    provider: "gosend", serviceType: s.service_type ?? "instant", serviceName: s.service_name ?? "GoSend",
    price: Math.round(s.price ?? 0), currency: "IDR", estimatedDelivery: s.estimated_delivery_time ?? "< 1 jam", available: s.is_available ?? true,
  }));
}
 
async function fetchGrabRates(origin: Coordinate, destination: Coordinate, weightKg: number): Promise<ShippingRate[]> {
  const token = await getGrabToken();
  const merchantId = GRAB_MERCHANT_ID.value();
  const r = await axios.post(
    `${grabBase()}/v1/deliveries/quotes`,
    { merchantID: merchantId, serviceType: "INSTANT", packages: [{ name: "Paket", description: "Paket Gogama", quantity: 1, price: 0, dimensions: { height: 10, width: 10, depth: 10, weight: weightKg * 1000 } }], origin: { address: origin.address, coordinates: { latitude: origin.latitude, longitude: origin.longitude } }, destination: { address: destination.address, coordinates: { latitude: destination.latitude, longitude: destination.longitude } } },
    { headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" } }
  );
  return (r.data.quotes ?? []).map((q: any): ShippingRate => ({
    provider: "grab", serviceType: q.serviceType ?? "INSTANT", serviceName: `GrabExpress ${q.serviceType ?? ""}`,
    price: Math.round(q.amount ?? 0), currency: "IDR", estimatedDelivery: "< 1 jam", available: true,
  }));
}
 
// ─────────────────────────────────────────────────────────────────
// FUNCTION 2: Booking driver instan
// ─────────────────────────────────────────────────────────────────
export const bookInstantDelivery = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login diperlukan.");
 
    const { orderId, provider, serviceType, origin, destination, packageInfo } = request.data as {
      orderId: string; provider: "gosend" | "grab"; serviceType: string;
      origin: Coordinate & { contactName: string; contactPhone: string };
      destination: Coordinate & { contactName: string; contactPhone: string };
      packageInfo: { description: string; weightKg: number; value: number };
    };
 
    if (!orderId || !provider) throw new HttpsError("invalid-argument", "Data tidak lengkap.");
 
    const orderDoc = await db.collection("orders").doc(orderId).get();
    if (!orderDoc.exists) throw new HttpsError("not-found", "Order tidak ditemukan.");
 
    const order = orderDoc.data()!;
    if (order.deliveryBookingId) {
      return { success: true, bookingId: order.deliveryBookingId, provider: order.deliveryProvider, message: "Sudah dibooking." };
    }
 
    try {
      let result: { bookingId: string; trackingUrl?: string; driverInfo?: any };
      if (provider === "gosend") {
        result = await bookGoSend(orderId, origin, destination, packageInfo, serviceType);
      } else {
        result = await bookGrab(orderId, origin, destination, packageInfo, serviceType);
      }
 
      await db.collection("orders").doc(orderId).update({
        deliveryBookingId: result.bookingId,
        deliveryProvider: provider,
        deliveryTrackingUrl: result.trackingUrl ?? "",
        deliveryDriverInfo: result.driverInfo ?? {},
        status: "Dikirim",
        updatedAt: FieldValue.serverTimestamp(),
      });
 
      return { success: true, bookingId: result.bookingId, provider, trackingUrl: result.trackingUrl };
    } catch (err: any) {
      logger.error(`Booking ${provider} gagal:`, err);
      throw new HttpsError("internal", `Gagal booking: ${err.message}`);
    }
  }
);
 
async function bookGoSend(orderId: string, origin: any, destination: any, pkg: any, serviceType: string) {
  const token = await getGoSendToken();
  const merchantId = GOSEND_MERCHANT_ID.value();
  const r = await axios.post(
    `${goSendBase()}/v1/merchant/orders`,
    { merchant_id: merchantId, merchant_order_id: orderId, service_type: serviceType, origin: { lat: origin.latitude, lng: origin.longitude, address: origin.address, name: origin.contactName, phone: origin.contactPhone }, destination: { lat: destination.latitude, lng: destination.longitude, address: destination.address, name: destination.contactName, phone: destination.contactPhone }, item: { name: "Paket Gogama", description: pkg.description, value: pkg.value, weight: pkg.weightKg, quantity: 1 } },
    { headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json", "X-Merchant-ID": merchantId } }
  );
  return { bookingId: r.data.order_id ?? r.data.id, trackingUrl: r.data.live_tracking_url, driverInfo: r.data.driver };
}
 
async function bookGrab(orderId: string, origin: any, destination: any, pkg: any, serviceType: string) {
  const token = await getGrabToken();
  const r = await axios.post(
    `${grabBase()}/v1/deliveries`,
    { merchantOrderID: orderId, serviceType, packages: [{ name: "Paket Gogama", description: pkg.description, quantity: 1, price: pkg.value, dimensions: { weight: pkg.weightKg * 1000, height: 10, width: 10, depth: 10 } }], origin: { address: origin.address, coordinates: { latitude: origin.latitude, longitude: origin.longitude }, contact: { firstName: origin.contactName, phone: origin.contactPhone } }, destination: { address: destination.address, coordinates: { latitude: destination.latitude, longitude: destination.longitude }, contact: { firstName: destination.contactName, phone: destination.contactPhone } } },
    { headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json", "X-Merchant-ID": GRAB_MERCHANT_ID.value() } }
  );
  return { bookingId: r.data.deliveryID ?? r.data.id, trackingUrl: r.data.trackingURL, driverInfo: r.data.driver };
}
 
// ─────────────────────────────────────────────────────────────────
// FUNCTION 3: Batalkan booking
// ─────────────────────────────────────────────────────────────────
export const cancelDelivery = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login diperlukan.");
 
    const { orderId } = request.data as { orderId: string };
    const orderDoc = await db.collection("orders").doc(orderId).get();
    if (!orderDoc.exists) throw new HttpsError("not-found", "Order tidak ditemukan.");
 
    const order = orderDoc.data()!;
    const provider = order.deliveryProvider as string | undefined;
    const bookingId = order.deliveryBookingId as string | undefined;
 
    if (!provider || !bookingId) throw new HttpsError("failed-precondition", "Tidak ada booking aktif.");
 
    if (provider === "gosend") {
      const token = await getGoSendToken();
      await axios.post(`${goSendBase()}/v1/merchant/orders/${bookingId}/cancel`, {}, { headers: { Authorization: `Bearer ${token}`, "X-Merchant-ID": GOSEND_MERCHANT_ID.value() } });
    } else {
      const token = await getGrabToken();
      await axios.delete(`${grabBase()}/v1/deliveries/${bookingId}`, { headers: { Authorization: `Bearer ${token}` } });
    }
 
    await db.collection("orders").doc(orderId).update({
      deliveryBookingId: FieldValue.delete(),
      deliveryCancelled: true,
      updatedAt: FieldValue.serverTimestamp(),
    });
 
    return { success: true };
  }
);
 
// ─────────────────────────────────────────────────────────────────
// FUNCTION 4: Track delivery
// ─────────────────────────────────────────────────────────────────
export const trackDelivery = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Login diperlukan.");
 
    const { orderId } = request.data as { orderId: string };
    const orderDoc = await db.collection("orders").doc(orderId).get();
    if (!orderDoc.exists) throw new HttpsError("not-found", "Order tidak ditemukan.");
 
    const order = orderDoc.data()!;
    const provider = order.deliveryProvider as string | undefined;
    const bookingId = order.deliveryBookingId as string | undefined;
 
    if (!provider || !bookingId) return { hasDelivery: false };
 
    try {
      if (provider === "gosend") {
        const token = await getGoSendToken();
        const r = await axios.get(`${goSendBase()}/v1/merchant/orders/${bookingId}`, { headers: { Authorization: `Bearer ${token}`, "X-Merchant-ID": GOSEND_MERCHANT_ID.value() } });
        return { hasDelivery: true, status: r.data.status, driverName: r.data.driver?.name, driverPhone: r.data.driver?.phone, driverPlate: r.data.driver?.vehicle_plate, trackingUrl: r.data.live_tracking_url };
      } else {
        const token = await getGrabToken();
        const r = await axios.get(`${grabBase()}/v1/deliveries/${bookingId}`, { headers: { Authorization: `Bearer ${token}` } });
        return { hasDelivery: true, status: r.data.status, driverName: r.data.driver?.name, driverPhone: r.data.driver?.phone, trackingUrl: r.data.trackingURL };
      }
    } catch {
      return { hasDelivery: true, provider, status: "unknown", trackingUrl: order.deliveryTrackingUrl ?? "" };
    }
  }
);