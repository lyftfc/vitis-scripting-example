#include <vector>
#include "xcl2.hpp"

#define N_TX 100000
#define N_RX 100000
#define DEFAULT_XCLBIN  "./hw_build/endianess_trial.xclbin"

struct __attribute__((packed)) entry_t {
	uint32_t data;
};

int main(int argc, char **argv) {

	const char *xclbinPath;
	if (argc != 2)
		xclbinPath = DEFAULT_XCLBIN;
	else
		xclbinPath = argv[1];

	// I/O Data Vectors
	std::vector<entry_t, aligned_allocator<entry_t> > reqs(N_TX), rets(N_RX);

	// Populate test cases
	for (uint32_t i = 0; i < N_TX; i++)
		reqs[i].data = i;

	// OpenCL Host Code Begins.
	cl_int err;
	cl::Device device;
	cl::Context context;
	cl::CommandQueue q;
	cl::Program program;
	// Kernels
	cl::Kernel krnl_dual_fifo;
	cl::Kernel krnl_feeder;
	cl::Kernel krnl_poller;

	// get_xil_devices() is a utility API which will find the xilinx
	// platforms and will return list of devices connected to Xilinx platform
	auto devices = xcl::get_xil_devices();

	// read_binary_file() is a utility API which will load the binaryFile
	// and will return the pointer to file buffer.
	auto fileBuf = xcl::read_binary_file(xclbinPath);
	cl::Program::Binaries bins{{fileBuf.data(), fileBuf.size()}};
	bool valid_device = false;
	for (unsigned int i = 0; i < devices.size(); i++) {
		device = devices[i];
		// Creating Context and Command Queue for selected Device
		OCL_CHECK(err, context = cl::Context(device, NULL, NULL, NULL, &err));
		OCL_CHECK(err, q = cl::CommandQueue(context, device,
					CL_QUEUE_PROFILING_ENABLE |
					CL_QUEUE_OUT_OF_ORDER_EXEC_MODE_ENABLE,
					&err));
		std::cout << "Trying to program device[" << i
			<< "]: " << device.getInfo<CL_DEVICE_NAME>() << std::endl;
		cl::Program program(context, {device}, bins, NULL, &err);
		if (err != CL_SUCCESS) {
			std::cout << "Failed to program device[" << i << "] with xclbin file!\n";
		} else {
			std::cout << "Device[" << i << "]: program successful!\n";
			// Creating Kernel
			OCL_CHECK(err, krnl_dual_fifo =
					cl::Kernel(program, "krnl_dual_fifo", &err));
			OCL_CHECK(err, krnl_feeder = 
					cl::Kernel(program, "krnl_feeder", &err));
			OCL_CHECK(err, krnl_poller = 
					cl::Kernel(program, "krnl_poller", &err));
			valid_device = true;
			break; // we break because we found a valid device
		}
	}
	if (!valid_device) {
		std::cout << "Failed to program any device found, exit!\n";
		exit(EXIT_FAILURE);
	}

	printf("\nPress ENTER to continue after setting up ILA trigger...");
	getc(stdin);

	unsigned int inputSizeBytes = N_TX * sizeof(entry_t);
	unsigned int outputSizeBytes = N_RX * sizeof(entry_t);

	// Allocate Buffer in Global Memory
	// Buffers are allocated using CL_MEM_USE_HOST_PTR for efficient memory and
	// Device-to-host communication
	OCL_CHECK(err, cl::Buffer inBuff(context,
				CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY,
				inputSizeBytes, reqs.data(), &err));
	OCL_CHECK(err, cl::Buffer outBuff(context,
				CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY,
				outputSizeBytes, rets.data(), &err));

	// Setting Kernel Arguments
	OCL_CHECK(err, err = krnl_feeder.setArg(0, inBuff));
	OCL_CHECK(err, err = krnl_feeder.setArg(1, N_TX));
	OCL_CHECK(err, err = krnl_poller.setArg(0, outBuff));
	OCL_CHECK(err, err = krnl_poller.setArg(1, N_RX));

	// Copy input data to device global memory (0 means from host)
	OCL_CHECK(err, err = q.enqueueMigrateMemObjects({inBuff}, 0));
	OCL_CHECK(err, err = q.finish());

	// Launch the Kernel (RTL Kernel with ap_ctrl_none need not enqueue)
	OCL_CHECK(err, err = q.enqueueTask(krnl_feeder));
	OCL_CHECK(err, err = q.enqueueTask(krnl_poller));

	printf("Kernel launched...\n");

	q.finish(); // Waiting for kernels to finish execution

	// Copy Result from Device Global Memory to Host Local Memory
	OCL_CHECK(err, err = q.enqueueMigrateMemObjects(
				{outBuff}, CL_MIGRATE_MEM_OBJECT_HOST));

	printf("Fetching results...\n");

	// OpenCL Host Code Ends
	q.finish();

	// Check the results
	for (int i = 0x10010; i < 0x10020; i++)
		printf("%x ", rets[i].data);
	printf("\n");

	return EXIT_SUCCESS;
}
