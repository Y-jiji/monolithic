#include <cuda.h>
#include <iostream>

// PTX kernel as a string (or load from file)
const char* ptx_source = "                              \n \
.version 7.0                                            \n \
.target sm_50                                           \n \
.address_size 64                                        \n \
.visible .entry vectorAdd(                              \n \
    .param .u64 vectorAdd_param_0,                      \n \
    .param .u64 vectorAdd_param_1,                      \n \
    .param .u64 vectorAdd_param_2                       \n \
) {                                                     \n \
    .reg .f32   %f<4>;                                  \n \
    .reg .b32   %r<5>;                                  \n \
    .reg .b64   %rd<11>;                                \n \
    ld.param.u64    %rd1, [vectorAdd_param_0];          \n \
    ld.param.u64    %rd2, [vectorAdd_param_1];          \n \
    ld.param.u64    %rd3, [vectorAdd_param_2];          \n \
    cvta.to.global.u64      %rd4, %rd3;                 \n \
    cvta.to.global.u64      %rd5, %rd2;                 \n \
    cvta.to.global.u64      %rd6, %rd1;                 \n \
    mov.u32         %r1, %ctaid.x;                      \n \
    mov.u32         %r2, %ntid.x;                       \n \
    mov.u32         %r3, %tid.x;                        \n \
    mad.lo.s32      %r4, %r2, %r1, %r3;                 \n \
    mul.wide.u32    %rd7, %r4, 4;                       \n \
    add.s64         %rd8, %rd6, %rd7;                   \n \
    ld.global.f32   %f1, [%rd8];                        \n \
    add.s64         %rd9, %rd5, %rd7;                   \n \
    ld.global.f32   %f2, [%rd9];                        \n \
    add.f32         %f3, %f1, %f2;                      \n \
    add.s64         %rd10, %rd4, %rd7;                  \n \
    st.global.f32   [%rd10], %f3;                       \n \
    ret;                                                \n \
}";

int main() {
    CUdevice cuDevice;
    CUcontext cuContext;
    CUmodule cuModule;
    CUfunction vectorAddKernel;

    CUresult        cuerr = CUresult::CUDA_SUCCESS;
    const char*     cumsg = nullptr;

    // Initialize CUDA driver API
    cuerr = cuInit(0);
    if (cuerr) {
        cuGetErrorString(cuerr, &cumsg);
        std::cout << "cuda error! " << cumsg << " @ line:" << __LINE__ << std::endl;
        return 1;
    }

    // Get GPU device
    cuerr = cuDeviceGet(&cuDevice, 0);
    if (cuerr) {
        cuGetErrorString(cuerr, &cumsg);
        std::cout << "cuda error! " << cumsg << " @ line:" << __LINE__ << std::endl;
        return 1;
    }

    // Create context
    cuerr = cuCtxCreate(&cuContext, 0, cuDevice);
    if (cuerr) {
        cuGetErrorString(cuerr, &cumsg);
        std::cout << "cuda error! " << cumsg << " @ line:" << __LINE__ << std::endl;
        return 1;
    }

    // Load PTX module
    cuerr = cuModuleLoadData(&cuModule, ptx_source);
    if (cuerr) {
        cuGetErrorString(cuerr, &cumsg);
        std::cout << "cuda error! " << cumsg << " @ line:" << __LINE__ << std::endl;
        return 1;
    }

    // Get the kernel function from PTX
    cuerr = cuModuleGetFunction(&vectorAddKernel, cuModule, "vectorAdd");
    if (cuerr) {
        cuGetErrorString(cuerr, &cumsg);
        std::cout << "cuda error! " << cumsg << " @ line:" << __LINE__ << std::endl;
        return 1;
    }

    // Define and allocate memory for input/output arrays
    const int N = 1024;
    int h_A[N], h_B[N], h_C[N];
    int* d_A; int* d_B; int* d_C;
    cudaMalloc(&d_A, N * sizeof(int));
    cudaMalloc(&d_B, N * sizeof(int));
    cudaMalloc(&d_C, N * sizeof(int));

    // Fill input arrays with sample data
    for (int i = 0; i < N; i++) {
        h_A[i] = i + 1;
        h_B[i] = i * 2 + 1;
    }

    // Copy data to device
    cudaMemcpy(d_A, h_A, N * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_B, h_B, N * sizeof(int), cudaMemcpyHostToDevice);

    // Set kernel parameters
    void* args[] = { &d_A, &d_B, &d_C, (void*) &N };

    // Launch the PTX kernel
    cuerr = cuLaunchKernel(vectorAddKernel,
        N / 256, 1, 1,   // Grid size (blocks)
        256, 1, 1,       // Block size (threads per block)
        0, nullptr,      // Shared memory size, stream
        args, nullptr);  // Kernel arguments
    if (cuerr) {
        cuGetErrorString(cuerr, &cumsg);
        std::cout << "cuda error! " << cumsg << " @ line:" << __LINE__ << std::endl;
        return 1;
    }

    // Copy result back to host
    cudaMemcpy(h_C, d_C, N * sizeof(int), cudaMemcpyDeviceToHost);

    // Verify the result
    for (int i = 0; i < N; i++) {
        if (h_C[i] != h_A[i] + h_B[i]) {
            std::cout << i << "\t: " << h_C[i] << " != " << h_A[i] + h_B[i] << std::endl;
        } else {
            std::cout << i << "\t: OK" << std::endl;
        }
    }

    // Clean up
    cudaFree(d_A); cudaFree(d_B); cudaFree(d_C);
    cuModuleUnload(cuModule);
    cuCtxDestroy(cuContext);

    std::cout << "Completed successfully!" << std::endl;
    return 0;
}
