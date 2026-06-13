"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.handleMidtransNotification = exports.createMidtransTransaction = void 0;
const https_1 = require("firebase-functions/v2/https");
const v2_1 = require("firebase-functions/v2");
const firestore_1 = require("firebase-admin/firestore");
const v2_2 = require("firebase-functions/v2");
const params_1 = require("firebase-functions/params");
// ─── Set default region ───────────────────────────────────────────
(0, v2_1.setGlobalOptions)({ region: "asia-southeast1" });
// ─────────────────────────────────────────────────────────────────
// Setup sekali:
//   firebase functions:secrets:set MIDTRANS_SERVER_KEY
//   firebase functions:secrets:set MIDTRANS_IS_PRODUCTION   (value: "false" atau "true")
// ─────────────────────────────────────────────────────────────────
const MIDTRANS_SERVER_KEY = (0, params_1.defineString)("MIDTRANS_SERVER_KEY");
const MIDTRANS_IS_PRODUCTION = (0, params_1.defineString)("MIDTRANS_IS_PRODUCTION", { default: "false" });
// @ts-ignore
const midtransClient = require("midtrans-client");
const db = (0, firestore_1.getFirestore)();
// ─────────────────────────────────────────────────────────────────
// FUNCTION 1: Buat transaksi Midtrans Snap
// ─────────────────────────────────────────────────────────────────
exports.createMidtransTransaction = (0, https_1.onCall)({ region: "asia-southeast1" }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "User harus login.");
    }
    const { orderId } = request.data;
    if (!orderId) {
        throw new https_1.HttpsError("invalid-argument", "orderId wajib diisi.");
    }
    const orderDoc = await db.collection("orders").doc(orderId).get();
    if (!orderDoc.exists) {
        throw new https_1.HttpsError("not-found", "Order tidak ditemukan.");
    }
    const order = orderDoc.data();
    if (order.customerId !== request.auth.uid) {
        throw new https_1.HttpsError("permission-denied", "Akses ditolak.");
    }
    if (order.paymentStatus === "paid") {
        throw new https_1.HttpsError("already-exists", "Order ini sudah dibayar.");
    }
    const userDoc = await db.collection("user").doc(request.auth.uid).get();
    const user = userDoc.data() ?? {};
    const snap = new midtransClient.Snap({
        isProduction: MIDTRANS_IS_PRODUCTION.value() === "true",
        serverKey: MIDTRANS_SERVER_KEY.value(),
    });
    const itemDetails = order.products.map((p) => ({
        id: p.productId,
        price: Math.round(p.price),
        quantity: p.quantity,
        name: p.name.substring(0, 50),
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
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        });
        v2_2.logger.info(`Midtrans token dibuat untuk order: ${orderId}`);
        return { token: transaction.token, redirectUrl: transaction.redirect_url };
    }
    catch (err) {
        v2_2.logger.error("Gagal membuat Midtrans token:", err);
        throw new https_1.HttpsError("internal", `Gagal membuat transaksi: ${err.message}`);
    }
});
// ─────────────────────────────────────────────────────────────────
// FUNCTION 2: Webhook notifikasi dari Midtrans
// Daftarkan URL di Midtrans Dashboard > Payment Notification URL
// ─────────────────────────────────────────────────────────────────
exports.handleMidtransNotification = (0, https_1.onRequest)({ region: "asia-southeast1" }, async (req, res) => {
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
        const orderId = statusResponse.order_id;
        const transactionStatus = statusResponse.transaction_status;
        const fraudStatus = statusResponse.fraud_status;
        v2_2.logger.info(`Midtrans notif | Order: ${orderId} | Status: ${transactionStatus}`);
        let paymentStatus = "unpaid";
        let orderStatus = null;
        if (transactionStatus === "capture") {
            paymentStatus = fraudStatus === "accept" ? "paid" : "fraud";
            if (paymentStatus === "paid")
                orderStatus = "Processing";
        }
        else if (transactionStatus === "settlement") {
            paymentStatus = "paid";
            orderStatus = "Processing";
        }
        else if (["cancel", "deny", "expire"].includes(transactionStatus)) {
            paymentStatus = "failed";
            orderStatus = "Cancelled";
        }
        else if (transactionStatus === "pending") {
            paymentStatus = "pending_payment";
        }
        const updateData = {
            paymentStatus,
            midtransTransactionStatus: transactionStatus,
            midtransPaymentType: statusResponse.payment_type,
            updatedAt: firestore_1.FieldValue.serverTimestamp(),
        };
        if (orderStatus)
            updateData.status = orderStatus;
        await db.collection("orders").doc(orderId).update(updateData);
        res.status(200).json({ message: "OK" });
    }
    catch (err) {
        v2_2.logger.error("Error memproses notifikasi Midtrans:", err);
        res.status(500).json({ message: "Internal Server Error" });
    }
});
//# sourceMappingURL=midtrans.js.map