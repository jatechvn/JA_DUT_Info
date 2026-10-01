package com.jatech.srf;

import java.net.DatagramSocket;
import java.net.DatagramPacket;
import java.net.InetAddress;

public final class SrfReceiverTest {
    static void check(boolean ok) { if (!ok) throw new AssertionError(); }
    public static void main(String[] args) throws Exception {
        byte[] frame = new byte[19];
        frame[3] = 0x25; frame[4] = 0x39; frame[5] = 0x0A;
        frame[14] = 70; // -99 dBm boundary; byte 6 is not RSSI.
        check(SrfReceiver.matches(frame, 19, "25390A"));
        check(!SrfReceiver.matches(frame, 18, "25390A"));
        check(!SrfReceiver.matches(frame, 20, "25390A"));
        check(!SrfReceiver.matches(frame, 19, "49CA0A"));
        frame[6] = (byte) 255; // A strong value in the wrong field must not pass.
        frame[14] = 69;
        check(!SrfReceiver.matches(frame, 19, "25390A"));
        frame[14] = (byte) 255;
        check(SrfReceiver.matches(frame, 19, "25390A"));
        frame[3] = 0x49; frame[4] = (byte) 0xCA;
        check(SrfReceiver.matches(frame, 19, "49CA0A"));
        try (DatagramSocket receiver = new DatagramSocket(0);
             DatagramSocket sender = new DatagramSocket()) {
            byte[] oversized = java.util.Arrays.copyOf(frame, 20);
            sender.send(new DatagramPacket(oversized, 20,
                    InetAddress.getLoopbackAddress(), receiver.getLocalPort()));
            for (int i = 0; i < 5; i++) sender.send(new DatagramPacket(frame, 19,
                    InetAddress.getLoopbackAddress(), receiver.getLocalPort()));
            check(SrfReceiver.receive(receiver, "49CA0A", System.nanoTime() + 1000000000L) == 5);
            // A fresh invocation cannot reuse the previous count; silence times out.
            check(SrfReceiver.receive(receiver, "49CA0A", System.nanoTime() + 50000000L) == 0);
            for (int i = 0; i < 4; i++) sender.send(new DatagramPacket(frame, 19,
                    InetAddress.getLoopbackAddress(), receiver.getLocalPort()));
            check(SrfReceiver.receive(receiver, "49CA0A", System.nanoTime() + 50000000L) == 4);
        }
        System.out.println("SRF packet and UDP regression checks passed");
    }
}
