import os
import sys

#Configuration
SOURCE_DIR = "src"
BUILD_DIR = "bin"
BOOTLOADER_SRC = os.path.join(SOURCE_DIR, "boot.asm")
BOOTLOADER_BIN = os.path.join(BUILD_DIR, "boot.bin")
KERNEL_SRC = os.path.join(SOURCE_DIR, "kernel.asm")
KERNEL_BIN = os.path.join(BUILD_DIR, "kernel.bin")

def assemble(input_file, output_file):
	print(f"[ASM] Assembling {input_file}")

	command = f"nasm -f bin {input_file} -o {output_file}"

	result=os.system(command)

	if result != 0:
		print(f"[ERROR] Failed To Assembly {input_file}")
		sys.exit(1)

def ensure_build_dir():
	if not os.path.exists(BUILD_DIR):
		os.makedirs(BUILD_DIR)

FLOPPY_SIZE = 1474560

def create_disk_image():
	print(f"[BUILD] Creating {FLOPPY_SIZE} Byte Disk Image...")

	boot_bin = BOOTLOADER_BIN
	kernel_bin = KERNEL_BIN
	output_img = os.path.join(BUILD_DIR, "main_floppy.img")

	with open(output_img, 'wb') as img:
		if os.path.exists(boot_bin):
			with open(boot_bin, 'rb') as f:
				boot_data = f.read()

				if len(boot_data) > 512:
					print(f"[ERROR] Bootloader Is {len(boot_data)} Bytes!" "Must Be <= 512 Bytes.")
					sys.exit(1)

				img.write(boot_data)
				print(f" + Wrote Bootloader ({len(boot_data)}) Bytes")

				if len(boot_data) < 512:
					padding = 512 - len(boot_data)
					img.write(b'\x00' * padding)
					print(f" + Padded Boot Sector With {padding} Bytes")

		else:
			print(f"[ERROR] {boot_bin} Not Found.")
			sys.exit()


		if os.path.exists(kernel_bin):
			with open(kernel_bin, 'rb') as f:
				kernel_data = f.read()
				img.write(kernel_data)
				print(f" + Wrote Kernel  ({len(kernel_data)}) Bytes")


		current_pos = img.tell()
		remaining = FLOPPY_SIZE - current_pos

		if remaining < 0:
			print("[ERROR] Image Exceeds Floppy Size Limit!")
			sys.exit(1)


		img.write(b'\x00' * remaining)
		print(f" + Padded Disk With {remaining} Bytes Of Zeroes")

	print(f"[SUCCESS] Created {output_img}")

def clean_project():

	print("[BUILD] Cleaning Up Project...")

	files_to_remove = [
		BOOTLOADER_BIN,
		KERNEL_BIN,
		"main_floppy.img"
	]

	for file_path in files_to_remove:
		if os.path.exists(file_path):
			os.remove(file_path)
			print(f" - Removed {file_path}")

		else:
			print(f" - {file_path} Already Clean")
def main():
	ensure_build_dir()

	if len(sys.argv) > 1:
		if sys.argv[1] == "clean":
			clean_project()
			return

		else:
			print(f"[ERROR] Unkown Command: {sys.argv[1]}")
			print(f"Usage: Python build.py [clean]")
			sys.exit(1)

	#compile the bootloader
	assemble(BOOTLOADER_SRC, BOOTLOADER_BIN)

	#compile the kernel
	assemble(KERNEL_SRC, KERNEL_BIN)

	create_disk_image()

if __name__ == "__main__":
	main()
