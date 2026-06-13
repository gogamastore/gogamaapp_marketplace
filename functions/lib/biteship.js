"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.biteshipWebhook = exports.trackBiteshipOrder = exports.createBiteshipOrder = exports.getBiteshipRates = exports.searchBiteshipArea = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-admin/firestore");
const v2_1 = require("firebase-functions/v2");
const params_1 = require("firebase-functions/params");
const axios_1 = __importDefault(require("axios"));
const db = (0, firestore_1.getFirestore)();
// ─────────────────────────────────────────────────────────────────
// Setup:
//   firebase functions:secrets:set BITESHIP_API_KEY
//   firebase functions:secrets:set BITESHIP_IS_PRODUCTION   (false/true)
//   firebase functions:secrets:set BITESHIP_ORIGIN_AREA_ID
//   firebase functions:secrets:set BITESHIP_ORIGIN_ADDRESS
//   firebase functions:secrets:set BITESHIP_ORIGIN_CONTACT_NAME
//   firebase functions:secrets:set BITESHIP_ORIGIN_CONTACT_PHONE
// ─────────────────────────────────────────────────────────────────
const BITESHIP_API_KEY = (0, params_1.defineString)("BITESHIP_API_KEY");
const BITESHIP_IS_PRODUCTION = (0, params_1.defineString)("BITESHIP_IS_PRODUCTION", { default: "true" });
const BITESHIP_ORIGIN_AREA_ID = (0, params_1.defineString)("BITESHIP_ORIGIN_AREA_ID");
const BITESHIP_ORIGIN_ADDRESS = (0, params_1.defineString)("BITESHIP_ORIGIN_ADDRESS");
const BITESHIP_ORIGIN_CONTACT_NAME = (0, params_1.defineString)("BITESHIP_ORIGIN_CONTACT_NAME", { default: "Gogama Store" });
const BITESHIP_ORIGIN_CONTACT_PHONE = (0, params_1.defineString)("BITESHIP_ORIGIN_CONTACT_PHONE");
// Biteship pakai URL yang sama untuk sandbox & production,
// dibedakan hanya dari prefix API key (biteship_test. vs biteship_live.)
const biteshipBaseUrl = () => {
    const isProduction = BITESHIP_IS_PRODUCTION.value() === "true";
    v2_1.logger.info(`Biteship API initialized. Production mode: ${isProduction}`);
    return "https://api.biteship.com";
};
const biteshipApi = () => axios_1.default.create({
    baseURL: biteshipBaseUrl(),
    headers: {
        Authorization: `Bearer ${BITESHIP_API_KEY.value()}`,
        "Content-Type": "application/json",
    },
});
// ─────────────────────────────────────────────────────────────────
// FUNCTION 1: Cari area Biteship (autocomplete kota/kecamatan)
// ─────────────────────────────────────────────────────────────────
exports.searchBiteshipArea = (0, https_1.onCall)({ region: "asia-southeast1" }, async (request) => {
    if (!request.auth)
        throw new https_1.HttpsError("unauthenticated", "Login diperlukan.");
    const { input } = request.data;
    if (!input || input.length < 3) {
        throw new https_1.HttpsError("invalid-argument", "Input minimal 3 karakter.");
    }
    try {
        const api = biteshipApi();
        const resp = await api.get("/v1/maps/areas", {
            params: { countries: "ID", input, type: "single" },
        });
        const areas = (resp.data.areas ?? []).map((a) => ({
            id: a.id,
            name: a.name,
            postalCode: a.postal_code,
            adminName: [
                a.administrative_division_level_1_name,
                a.administrative_division_level_2_name,
            ]
                .filter(Boolean)
                .join(", "),
        }));
        return { areas };
    }
    catch (err) {
        v2_1.logger.error("searchBiteshipArea error:", err?.response?.data ?? err.message);
        throw new https_1.HttpsError("internal", "Gagal mencari area.");
    }
});
// ─────────────────────────────────────────────────────────────────
// FUNCTION 2: Ambil tarif semua kurir
// ─────────────────────────────────────────────────────────────────
exports.getBiteshipRates = (0, https_1.onCall)({ region: "asia-southeast1" }, async (request) => {
    if (!request.auth)
        throw new https_1.HttpsError("unauthenticated", "Login diperlukan.");
    const { destinationAreaId, items, couriers } = request.data;
    if (!destinationAreaId || !items?.length) {
        throw new https_1.HttpsError("invalid-argument", "destinationAreaId dan items wajib diisi.");
    }
    const defaultCouriers = couriers?.length
        ? couriers
        : ["jne", "jnt", "sicepat", "anteraja", "pos", "tiki", "ninja", "lion", "wahana"];
    try {
        const api = biteshipApi();
        const resp = await api.post("/v1/rates/couriers", {
            origin_area_id: BITESHIP_ORIGIN_AREA_ID.value(),
            destination_area_id: destinationAreaId,
            couriers: defaultCouriers.join(","),
            items: items.map((item) => ({
                id: item.productId,
                name: item.name,
                description: item.name,
                value: item.price,
                length: 10,
                width: 10,
                height: 10,
                weight: item.weightGram,
                quantity: item.quantity,
            })),
        });
        const rates = (resp.data.pricing ?? [])
            .filter((r) => r.available)
            .map((r) => {
            const rangeParts = (r.shipment_duration_range ?? "1-7").split("-");
            return {
                courierId: r.courier_code,
                courierName: r.courier_name,
                courierServiceCode: r.courier_service_code,
                serviceName: r.courier_service_name,
                description: r.description ?? "",
                price: Math.round(r.price ?? 0),
                originalPrice: Math.round(r.original_price ?? r.price ?? 0),
                discount: Math.round((r.original_price ?? 0) - (r.price ?? 0)),
                minDay: parseInt(rangeParts[0] ?? "1"),
                maxDay: parseInt(rangeParts[1] ?? rangeParts[0] ?? "7"),
                estimatedDelivery: r.shipment_duration_unit === "days"
                    ? `${r.shipment_duration_range} hari`
                    : (r.shipment_duration_range ?? "-"),
                available: r.available ?? true,
                logo: r.courier_logo,
                category: categorizeService(r.courier_service_name ?? ""),
            };
        })
            .sort((a, b) => a.price - b.price);
        v2_1.logger.info(`Biteship rates: ${rates.length} layanan untuk area ${destinationAreaId}`);
        return { rates };
    }
    catch (err) {
        const errData = err?.response?.data;
        v2_1.logger.error("getBiteshipRates error:", errData ?? err.message);
        throw new https_1.HttpsError("internal", errData?.error ?? "Gagal mengambil tarif kurir.");
    }
});
// ─────────────────────────────────────────────────────────────────
// FUNCTION 3: Buat order Biteship + request pickup otomatis
// Dipanggil admin setelah order dikonfirmasi siap dikirim
// ─────────────────────────────────────────────────────────────────
exports.createBiteshipOrder = (0, https_1.onCall)({ region: "asia-southeast1" }, async (request) => {
    if (!request.auth)
        throw new https_1.HttpsError("unauthenticated", "Login diperlukan.");
    const { orderId } = request.data;
    const orderDoc = await db.collection("orders").doc(orderId).get();
    if (!orderDoc.exists)
        throw new https_1.HttpsError("not-found", "Order tidak ditemukan.");
    const order = orderDoc.data();
    // Cegah double booking
    if (order.biteshipOrderId) {
        return {
            success: true,
            biteshipOrderId: order.biteshipOrderId,
            waybillId: order.waybillId,
            message: "Pickup sudah dibooking.",
        };
    }
    if (!order.biteshipCourierCode || !order.biteshipServiceCode) {
        throw new https_1.HttpsError("failed-precondition", "Data kurir belum dipilih di order ini.");
    }
    const customerDetails = order.customerDetails ?? {};
    const originContactName = BITESHIP_ORIGIN_CONTACT_NAME.value();
    const originContactPhone = BITESHIP_ORIGIN_CONTACT_PHONE.value();
    const originAddress = BITESHIP_ORIGIN_ADDRESS.value();
    const originAreaId = BITESHIP_ORIGIN_AREA_ID.value();
    try {
        const api = biteshipApi();
        const resp = await api.post("/v1/orders", {
            shipper_contact_name: originContactName,
            shipper_contact_phone: originContactPhone,
            shipper_contact_email: "",
            shipper_organization: "Gogama Store",
            origin_contact_name: originContactName,
            origin_contact_phone: originContactPhone,
            origin_address: originAddress,
            origin_area_id: originAreaId,
            origin_note: "Hubungi pengirim sebelum pickup",
            destination_contact_name: customerDetails.name ?? "",
            destination_contact_phone: customerDetails.whatsapp ?? "",
            destination_contact_email: "",
            destination_address: customerDetails.address ?? "",
            destination_area_id: order.destinationAreaId ?? "",
            destination_note: order.deliveryNotes ?? "",
            courier_company: order.biteshipCourierCode,
            courier_type: order.biteshipServiceCode,
            courier_insurance: 0,
            delivery_type: "now",
            order_note: `Order #${orderId} dari Gogama Store`,
            metadata: { orderId },
            items: order.products.map((p) => ({
                id: p.productId,
                name: p.name,
                description: p.name,
                value: Math.round(p.price),
                length: 10,
                width: 10,
                height: 10,
                weight: 200,
                quantity: p.quantity,
            })),
        });
        const biteshipOrder = resp.data;
        await db.collection("orders").doc(orderId).update({
            biteshipOrderId: biteshipOrder.id,
            waybillId: biteshipOrder.waybill_id ?? "",
            biteshipStatus: biteshipOrder.status,
            biteshipCourierTrackingId: biteshipOrder.courier?.tracking_id ?? "",
            deliveryTrackingUrl: `https://biteship.com/tracking/${biteshipOrder.waybill_id ?? ""}`,
            status: "Dikirim",
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
        v2_1.logger.info(`Biteship order: ${biteshipOrder.id} | Waybill: ${biteshipOrder.waybill_id}`);
        return {
            success: true,
            biteshipOrderId: biteshipOrder.id,
            waybillId: biteshipOrder.waybill_id,
            status: biteshipOrder.status,
            trackingUrl: `https://biteship.com/tracking/${biteshipOrder.waybill_id ?? ""}`,
        };
    }
    catch (err) {
        const errData = err?.response?.data;
        v2_1.logger.error("createBiteshipOrder error:", errData ?? err.message);
        throw new https_1.HttpsError("internal", errData?.error ?? "Gagal membuat order Biteship.");
    }
});
// ─────────────────────────────────────────────────────────────────
// FUNCTION 4: Tracking resi
// ─────────────────────────────────────────────────────────────────
exports.trackBiteshipOrder = (0, https_1.onCall)({ region: "asia-southeast1" }, async (request) => {
    if (!request.auth)
        throw new https_1.HttpsError("unauthenticated", "Login diperlukan.");
    const { orderId } = request.data;
    const orderDoc = await db.collection("orders").doc(orderId).get();
    if (!orderDoc.exists)
        throw new https_1.HttpsError("not-found", "Order tidak ditemukan.");
    const order = orderDoc.data();
    const biteshipOrderId = order.biteshipOrderId;
    const waybillId = order.waybillId;
    if (!biteshipOrderId)
        return { hasDelivery: false };
    try {
        const api = biteshipApi();
        const resp = await api.get(`/v1/orders/${biteshipOrderId}`);
        const biteshipData = resp.data;
        // Ambil history tracking jika waybill tersedia
        let trackingHistory = [];
        if (waybillId) {
            try {
                const trackResp = await api.get(`/v1/trackings/${waybillId}`);
                trackingHistory = trackResp.data.history ?? [];
            }
            catch {
                // history belum tersedia, lanjutkan
            }
        }
        // Sync status ke Firestore jika berubah
        const newStatus = mapBiteshipStatus(biteshipData.status);
        if (newStatus && newStatus !== order.status) {
            await db.collection("orders").doc(orderId).update({
                status: newStatus,
                biteshipStatus: biteshipData.status,
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            });
        }
        return {
            hasDelivery: true,
            biteshipOrderId,
            waybillId: waybillId ?? "",
            status: biteshipData.status,
            courierName: biteshipData.courier?.company ?? order.biteshipCourierCode,
            driverName: biteshipData.courier?.driver_name ?? "",
            driverPhone: biteshipData.courier?.driver_phone ?? "",
            trackingUrl: `https://biteship.com/tracking/${waybillId ?? ""}`,
            history: trackingHistory.map((h) => ({
                timestamp: h.updated_at,
                status: h.status,
                note: h.note ?? "",
            })),
        };
    }
    catch (err) {
        v2_1.logger.error("trackBiteshipOrder error:", err?.response?.data ?? err.message);
        return {
            hasDelivery: true,
            biteshipOrderId,
            waybillId: waybillId ?? "",
            status: "unknown",
            trackingUrl: order.deliveryTrackingUrl ?? "",
            history: [],
        };
    }
});
// ─────────────────────────────────────────────────────────────────
// FUNCTION 5: Webhook dari Biteship (status update otomatis)
// Daftarkan di Biteship Dashboard → Settings → Webhook
// ─────────────────────────────────────────────────────────────────
exports.biteshipWebhook = (0, https_1.onRequest)({ region: "asia-southeast1" }, async (req, res) => {
    if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
    }
    try {
        const event = req.body;
        v2_1.logger.info("Biteship webhook:", event.event, "| Order:", event.order?.id);
        const biteshipOrderId = event.order?.id;
        if (!biteshipOrderId) {
            res.status(200).json({ received: true });
            return;
        }
        const orderQuery = await db
            .collection("orders")
            .where("biteshipOrderId", "==", biteshipOrderId)
            .limit(1)
            .get();
        if (orderQuery.empty) {
            v2_1.logger.warn(`Order biteshipOrderId=${biteshipOrderId} tidak ditemukan.`);
            res.status(200).json({ received: true });
            return;
        }
        const orderDoc = orderQuery.docs[0];
        const newOrderStatus = mapBiteshipStatus(event.order?.status);
        const waybillId = event.order?.waybill_id;
        const updateData = {
            biteshipStatus: event.order?.status,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        };
        if (newOrderStatus)
            updateData.status = newOrderStatus;
        if (waybillId) {
            updateData.waybillId = waybillId;
            updateData.deliveryTrackingUrl = `https://biteship.com/tracking/${waybillId}`;
        }
        if (event.order?.courier?.tracking_id) {
            updateData.biteshipCourierTrackingId = event.order.courier.tracking_id;
        }
        await orderDoc.ref.update(updateData);
        v2_1.logger.info(`Webhook OK: ${biteshipOrderId} → ${event.order?.status} → ${newOrderStatus}`);
        res.status(200).json({ received: true });
    }
    catch (err) {
        v2_1.logger.error("biteshipWebhook error:", err);
        res.status(500).json({ error: "Internal Server Error" });
    }
});
// ─── Helpers ──────────────────────────────────────────────────────
function mapBiteshipStatus(s) {
    if (!s)
        return null;
    const lower = s.toLowerCase();
    if (lower.includes("allocating") || lower.includes("waiting_pickup"))
        return "Diproses";
    if (lower.includes("picked_up") || lower.includes("on_process") || lower.includes("in_transit"))
        return "Dikirim";
    if (lower.includes("delivered"))
        return "Selesai";
    if (lower.includes("cancelled") || lower.includes("failed") || lower.includes("returned"))
        return "Dibatalkan";
    return null;
}
function categorizeService(name) {
    const s = name.toLowerCase();
    if (s.includes("same day") || s.includes("sameday"))
        return "same_day";
    if (s.includes("next day") || s.includes("express"))
        return "next_day";
    if (s.includes("cargo") || s.includes("freight"))
        return "cargo";
    return "reguler";
}
//# sourceMappingURL=biteship.js.map