import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";
import { defineString } from "firebase-functions/params";
 
// ─── Set default region ───────────────────────────────────────────
setGlobalOptions({ region: "asia-southeast1" });
 
// ─────────────────────────────────────────────────────────────────
// Setup sekali:
//   firebase functions:secrets:set MIDTRANS_SERVER_KEY
//   firebase functions:secrets:set MIDTRANS_IS_PRODUCTION   (value: "false" atau "true")
// ─────────────────────────────────────────────────────────────────
const MIDTRANS_SERVER_KEY = defineString("MIDTRANS_SERVER_KEY");
const MIDTRANS_IS_PRODUCTION = defineString("MIDTRANS_IS_PRODUCTION", { default: "false" });
 
// @ts-ignore
const midtransClient = require("midtrans-client");
 
const db = getFirestore();
 
// ─────────────────────────────────────────────────────────────────
// FUNCTION 1: Buat transaksi Midtrans Snap
// ─────────────────────────────────────────────────────────────────
export const createMidtransTransaction = onCall(
  { region: "asia-southeast1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User harus login.");
    }
 
    const { orderId } = request.data as { orderId: string };
    if (!orderId) {
      throw new HttpsError("invalid-argument", "orderId wajib diisi.");
    }
 
    const orderDoc = await db.collection("orders").doc(orderId).get();
    if (!orderDoc.exists) {
      throw new HttpsError("not-found", "Order tidak ditemukan.");
    }
 
    const order = orderDoc.data()!;
 
    if (order.customerId !== request.auth.uid) {
      throw new HttpsError("permission-denied", "Akses ditolak.");
    }
    if (order.paymentStatus === "paid") {
      throw new HttpsError("already-exists", "Order ini sudah dibayar.");
    }
 
    const userDoc = await db.collection("user").doc(request.auth.uid).get();
    const user = userDoc.data() ?? {};
 
    const snap = new midtransClient.Snap({
      isProduction: MIDTRANS_IS_PRODUCTION.value() === "true",
      serverKey: MIDTRANS_SERVER_KEY.value(),
    });
 
    const itemDetails = (order.products as any[]).map((p: any) => ({
      id: p.productId,
      price: Math.round(p.price),
      quantity: p.quantity,
      name: (p.name as string).substring(0, 50),
    }));
 
    if (order.shippingFee && order.shippingFee > 0) {
      itemDetails.push({
        id: "SHIPPING",
        price: Math.round(order.shippingFee),
        quantity: 1,
        name: `Ongkir - ${order.shippingMethod ?? "Pengiriman"}`,
      });
    }
 
    const parameter = {
      transaction_details: {
        order_id: orderId,
        gross_amount: Math.round(order.total),
      },
      item_details: itemDetails,
      customer_details: {
        first_name: order.customerDetails?.name ?? user.name ?? "Pelanggan",
        email: user.email ?? "",
        phone: order.customerDetails?.whatsapp ?? user.whatsapp ?? "",
        billing_address: { address: order.customerDetails?.address ?? "" },
        shipping_address: { address: order.customerDetails?.address ?? "" },
      },
      enabled_payments: [
        "gopay", "shopeepay", "other_qris",
        "bca_va", "bni_va", "bri_va", "mandiri_bill", "permata_va", "other_va",
        "indomaret", "alfamart", "credit_card",
      ],
      callbacks: {
        finish: `gogama://payment-result?order_id=${orderId}`,
      },
      expiry: { unit: "hours", duration: 24 },
    };
 
    try {
      const transaction = await snap.createTransaction(parameter);
 
      await db.collection("orders").doc(orderId).update({
        midtransToken: transaction.token,
        midtransRedirectUrl: transaction.redirect_url,
        paymentStatus: "pending_payment",
        updatedAt: FieldValue.serverTimestamp(),
      });
 
      logger.info(`Midtrans token dibuat untuk order: ${orderId}`);
      return { token: transaction.token, redirectUrl: transaction.redirect_url };
    } catch (err: any) {
      logger.error("Gagal membuat Midtrans token:", err);
      throw new HttpsError("internal", `Gagal membuat transaksi: ${err.message}`);
    }
  }
);
 
// ─────────────────────────────────────────────────────────────────
// FUNCTION 2: Webhook notifikasi dari Midtrans
// Daftarkan URL di Midtrans Dashboard > Payment Notification URL
// ─────────────────────────────────────────────────────────────────
export const handleMidtransNotification = onRequest(
  { region: "asia-southeast1" },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }
 
    const coreApi = new midtransClient.CoreApi({
      isProduction: MIDTRANS_IS_PRODUCTION.value() === "true",
      serverKey: MIDTRANS_SERVER_KEY.value(),
    });
 
    try {
      const statusResponse = await coreApi.transaction.notification(req.body);
 
      const orderId: string = statusResponse.order_id;
      const transactionStatus: string = statusResponse.transaction_status;
      const fraudStatus: string = statusResponse.fraud_status;
 
      logger.info(`Midtrans notif | Order: ${orderId} | Status: ${transactionStatus}`);
 
      let paymentStatus = "unpaid";
      let orderStatus: string | null = null;
 
      if (transactionStatus === "capture") {
        paymentStatus = fraudStatus === "accept" ? "paid" : "fraud";
        if (paymentStatus === "paid") orderStatus = "Processing";
      } else if (transactionStatus === "settlement") {
        paymentStatus = "paid";
        orderStatus = "Processing";
      } else if (["cancel", "deny", "expire"].includes(transactionStatus)) {
        paymentStatus = "failed";
        orderStatus = "Cancelled";
      } else if (transactionStatus === "pending") {
        paymentStatus = "pending_payment";
      }
 
      const updateData: Record<string, any> = {
        paymentStatus,
        midtransTransactionStatus: transactionStatus,
        midtransPaymentType: statusResponse.payment_type,
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (orderStatus) updateData.status = orderStatus;
 
      await db.collection("orders").doc(orderId).update(updateData);
 
      res.status(200).json({ message: "OK" });
    } catch (err: any) {
      logger.error("Error memproses notifikasi Midtrans:", err);
      res.status(500).json({ message: "Internal Server Error" });
    }
  }
);
 