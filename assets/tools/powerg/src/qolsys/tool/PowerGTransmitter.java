package qolsys.tool;

import qolsys.powerGRadioController.PowergDeviceHandler;

public class PowerGTransmitter {
    public static void main(String[] args) {
        String action = args.length > 0 ? args[0] : "ping";
        String targetFreq = args.length > 1 ? args[1] : "all"; // "915", "868", "all"

        try {
            PowergDeviceHandler handler = PowergDeviceHandler.getPowergDeviceHandler();
            int total = PowergDeviceHandler.get_number_of_devices();

            if (total == 0) {
                System.out.println("RESULT:NO_DEVICE");
                System.exit(1);
            }

            int transmittedCount = 0;
            for (int i = 0; i < total; i++) {
                int freq = PowergDeviceHandler.get_device_radio_frequency(i);
                int ver = PowergDeviceHandler.get_device_radio_version(i);
                String sensorId = PowergDeviceHandler.get_sensor_id(i);
                if (sensorId == null || sensorId.isEmpty()) {
                    sensorId = (freq == 0) ? "1011231" : "1011230";
                }
                String freqStr = (freq == 0) ? "915" : (freq == 1 ? "868" : String.valueOf(freq));

                boolean match = targetFreq.equalsIgnoreCase("all") || targetFreq.equals(freqStr);

                if (action.equalsIgnoreCase("transmit")) {
                    if (match) {
                        System.out.println("Configuring & Transmitting on Radio index " + i + " (" + freqStr + "MHz, ID: " + sensorId + ")...");
                        if (PowergDeviceHandler.set_sensor_info(i, sensorId, (byte) 10) != 0) { throw new IllegalStateException("Sensor configuration failed: " + i); }
                        Thread.sleep(400);
                        int ret = PowergDeviceHandler.send_registration(i);
                        if (ret != 0) { throw new IllegalStateException("Registration failed: " + ret); }
                        Thread.sleep(1500);
                        System.out.println("RESULT:TRANSMIT_OK:INDEX=" + i + ":FREQ=" + freq + ":VER=" + ver + ":ID=" + sensorId + ":RET=" + ret);
                        transmittedCount++;
                    }
                } else {
                    System.out.println("RESULT:PING_OK:INDEX=" + i + ":FREQ=" + freq + ":VER=" + ver + ":ID=" + sensorId);
                }
            }

            if (action.equalsIgnoreCase("transmit") && transmittedCount == 0) {
                throw new IllegalStateException("No radio for requested frequency: " + targetFreq);
            }

            Thread.sleep(500);
            PowergDeviceHandler.stop_all_threads();
            Thread.sleep(300);
            System.exit(0);
        } catch (Throwable t) {
            System.out.println("RESULT:ERROR:" + t.getMessage());
            System.exit(2);
        }
    }
}
