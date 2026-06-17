The prebuilt image contains a fully configured ComfyUI installation and all required dependencies pre-installed.

Pull the Docker image.


ROCm 7.2.0 + Ubuntu 24.04
docker pull rocm/comfyui:comfyui-0.18.2.amd0_rocm7.2.0_ubuntu24.04

ROCm 7.1.0 + Ubuntu 22.04
Start a Docker container using the image.


ROCm 7.2.0 + Ubuntu 24.04
docker run -it --privileged \
--rm \
--device=/dev/kfd \
--device=/dev/dri \
--group-add video \
--cap-add=SYS_PTRACE \
--security-opt seccomp=unconfined \
--ipc=host \
-p 8188:8188 \
rocm/comfyui:comfyui-0.18.2.amd0_rocm7.2.0_ubuntu24.04

ROCm 7.1.0 + Ubuntu 22.04
