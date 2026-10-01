package com.jatech.srf;

import java.lang.reflect.Method;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetSocketAddress;
import java.net.SocketTimeoutException;
import java.util.Locale;
import java.util.Timer;
import java.util.TimerTask;

/** IQ4/IQ5 HSLX receive contract decoded from installed L10MMI APKs. */
public final class SrfReceiver {
    private static volatile boolean eventsAttempted;
    static boolean matches(byte[] bytes, int length, String airId) {
        if (length != 19) return false;
        String actual = String.format(Locale.ROOT, "%02X%02X%02X",
                bytes[3] & 255, bytes[4] & 255, bytes[5] & 255);
        int dbm = (bytes[14] & 255) / 2 - 134;
        return actual.equals(airId) && dbm >= -99;
    }

    static int receive(DatagramSocket socket, String airId, long deadline) throws Exception {
        int count = 0;
        byte[] bytes = new byte[65535]; // Do not truncate an oversized packet into a valid frame.
        while (count < 5 && System.nanoTime() < deadline) {
            socket.setSoTimeout((int) Math.max(1, Math.min(500,
                    (deadline - System.nanoTime()) / 1000000)));
            DatagramPacket packet = new DatagramPacket(bytes, bytes.length);
            try {
                socket.receive(packet);
                if (matches(bytes, packet.getLength(), airId)) count++;
            } catch (SocketTimeoutException ignored) {
                // Keep the monotonic deadline even when invalid packets keep arriving.
            }
        }
        return count;
    }

    static void event(int value) throws Exception {
        Class<?> parcelClass = Class.forName("android.os.Parcel");
        Class<?> binderClass = Class.forName("android.os.IBinder");
        Object binder = Class.forName("android.os.ServiceManager")
                .getMethod("getService", String.class).invoke(null, "srfservice_ttyHSLX");
        if (binder == null) throw new IllegalStateException("HSLX service missing");
        Object data = parcelClass.getMethod("obtain").invoke(null);
        Object reply = parcelClass.getMethod("obtain").invoke(null);
        try {
            parcelClass.getMethod("writeInterfaceToken", String.class)
                    .invoke(data, "srfservice_ttyHSLX");
            parcelClass.getMethod("writeInt", int.class).invoke(data, value);
            Method transact = binderClass.getMethod("transact", int.class,
                    parcelClass, parcelClass, int.class);
            if (!Boolean.TRUE.equals(transact.invoke(binder, 11, data, reply, 0))) {
                throw new IllegalStateException("Event transaction rejected");
            }
            int available = (Integer) parcelClass.getMethod("dataAvail").invoke(reply);
            if (available >= 4) {
                int firstWord = (Integer) parcelClass.getMethod("readInt").invoke(reply);
                if (firstWord < 0) throw new IllegalStateException("Binder exception reply");
            }
            // APK ignores the reply payload; transaction acceptance is not RF proof.
        } finally {
            parcelClass.getMethod("recycle").invoke(data);
            parcelClass.getMethod("recycle").invoke(reply);
        }
    }

    public static void main(String[] args) {
        if (args.length != 1 || !args[0].matches("25390A|49CA0A")) {
            System.out.println("RESULT:ERROR:invalid Air ID");
            System.exit(2);
        }
        // Bound the remote process even if a synchronous binder call hangs.
        Timer watchdog = new Timer(true);
        watchdog.schedule(new TimerTask() {
            public void run() {
                // A second thread can attempt cleanup even if enable/disable is stuck.
                Thread cleanup = new Thread(new Runnable() {
                    public void run() {
                        if (eventsAttempted) {
                            try { event(81); } catch (Exception ignored) { }
                        }
                    }
                });
                cleanup.setDaemon(true);
                cleanup.start();
            }
        }, 38000);
        watchdog.schedule(new TimerTask() {
            public void run() { System.exit(3); }
        }, 43000);
        int count = 0;
        boolean enabled = false;
        boolean clean = false;
        DatagramSocket socket = null;
        try {
            socket = new DatagramSocket(null);
            socket.setReuseAddress(false); // Never share MMI's receive port.
            socket.bind(new InetSocketAddress(9950));
            System.out.println("READY:" + args[0]);
            System.out.flush();
            // Host arms the listener before asking Golden to transmit.
            if (!"GO".equals(new java.io.BufferedReader(
                    new java.io.InputStreamReader(System.in)).readLine())) {
                throw new IllegalStateException("Host did not arm receiver");
            }
            enabled = true; // Try disable even if enable throws after changing service state.
            eventsAttempted = true;
            event(80);
            System.out.println("ARMED:" + args[0]);
            System.out.flush();
            count = receive(socket, args[0], System.nanoTime() + 30000000000L);
        } catch (Exception error) {
            System.out.println("RESULT:ERROR:" + error.getClass().getSimpleName());
        } finally {
            try {
                if (enabled) event(81);
                clean = true;
            } catch (Exception error) {
                System.out.println("RESULT:ERROR:cleanup failed");
            }
            // Retain port ownership until event teardown has returned.
            if (socket != null) socket.close();
        }
        if (count == 5 && clean) {
            System.out.println("RESULT:RX_OK:ID=" + args[0] + ":COUNT=5:CLEAN=1");
        } else {
            System.out.println("RESULT:RX_FAIL:COUNT=" + count);
        }
        watchdog.cancel();
        System.exit(count == 5 && clean ? 0 : 1);
    }
}
