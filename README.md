# I2C Master/Slave Controller & EEPROM Emulator

A fully synthesizable, bidirectional I2C Master and Memory-Mapped Slave written in Verilog. This project implements industry-standard I2C protocol features, including sub-addressing (register-level memory access) and Repeated Start (Sr) conditions, making the slave module behave exactly like a real physical EEPROM chip.

## 🚀 Key Features

* **Fully Synthesizable:** Designed for physical FPGA hardware. Eliminates multiple-driver synthesis errors completely.
* **Memory-Mapped Slave:** The slave features an internal `256-byte` SRAM array, allowing the master to read and write to specific memory registers using sub-addressing.
* **Oversampling Architecture:** The slave uses a high-speed system clock to oversample the `SCL` and `SDA` lines, ensuring rock-solid edge detection and preventing metastability without asynchronous clocking bugs.
* **Bi-Directional Communication:** Full support for Master-Transmitter / Slave-Receiver (Write) and Master-Receiver / Slave-Transmitter (Read) modes.
* **Repeated Start (Sr) Support:** The Master seamlessly transitions from writing a register address to reading data without releasing the bus, strictly following the I2C specification.
* **Phase 0 / Phase 1 Clocking:** Master ensures data (`SDA`) only transitions when the clock (`SCL`) is LOW, maximizing setup and hold times.

## 📁 Repository Structure

```text
├── rtl/
│   ├── i2c_top.v          # Top-level wrapper instantiating Master and Slave
│   ├── i2c_controller.v   # Controller interface grouping the Master and Clock Divider
│   ├── i2c_master.v       # The I2C Master State Machine (Handles Start, Stop, Sr, ACK/NACK)
│   ├── i2c_slave.v        # The I2C Memory-Mapped Slave (Oversampled, 256-byte internal memory)
│   └── i2c_clk_div.v      # Clock divider to generate the I2C SCL base frequency
├── tb/
│   └── tb_i2c.v           # Testbench demonstrating a Write transaction followed by a Read
└── README.md
