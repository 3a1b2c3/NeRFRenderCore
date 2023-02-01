﻿#include <stdio.h>
#include <iostream>
#include <cuda_runtime.h>
#include <device_launch_parameters.h>

#include <json/json.hpp>
#include <set>

#include "common.h"
#include "main.h"
#include "models/camera.cuh"
#include "models/dataset.h"
#include "models/cascaded-occupancy-grid.cuh"
#include "models/render-buffer.cuh"
#include "models/render-request.cuh"
#include "controllers/nerf-training-controller.h"
#include "controllers/nerf-rendering-controller.h"
#include "services/nerf-manager.cuh"
#include "utils/linalg.cuh"

#include "utils/coordinate-transformations.cuh"
#include "utils/linalg/transform4f.cuh"

#include <tiny-cuda-nn/common.h>
#include "utils/nerf-constants.cuh"
#include "models/cascaded-occupancy-grid.cuh"

using namespace tcnn;
using namespace nrc;
int main()
{
	// path to downloaded dataset
	std::string DATASET_PATH = "E:\\2022\\nerf-library\\testdata\\lego\\transforms.json";
	// path to write images to
	std::string OUTPUT_PATH = "H:\\";

	cudaStream_t stream;
	CUDA_CHECK_THROW(cudaStreamCreate(&stream));

	nrc::Dataset dataset = nrc::Dataset(DATASET_PATH);
	// auto dataset = nrc::Dataset("E:\\2022\\nerf-library\\FascinatedByFungi2022\\big-white-chanterelle\\transforms.json");
	auto nerf_manager = nrc::NeRFManager();

	// printf("%lu", grid.max_index());
	

	auto nerf = nerf_manager.create_trainable_nerf(stream, dataset.bounding_box);

	// set up training controller
	auto trainer = nrc::NeRFTrainingController(dataset, nerf);
	trainer.prepare_for_training(stream, NeRFConstants::batch_size);

	// set up rendering controller
	auto renderer = nrc::NeRFRenderingController();
	float* rgba;

	CUDA_CHECK_THROW(cudaMallocManaged(&rgba, 1024 * 1024 * 4 * sizeof(float)));
	auto render_buffer = nrc::RenderBuffer(1024, 1024, rgba);

	auto camera_transform = nrc::Matrix4f::Identity();
	auto cam6 = dataset.cameras[6];
	auto cam0 = dataset.cameras[6];

	// fetch nerfs as pointers
	std::vector<nrc::NeRF*> nerf_ptrs;
	for (auto& nerf : nerf_manager.get_nerfs()) {
		nerf_ptrs.emplace_back(nerf);
	}

	for (int i = 0; i < 1024 * 10; ++i) {
		trainer.train_step(stream);
		// every 16 training steps, update the occupancy grid

		if (i % 16 == 0 && i > 128) {
			// only threshold to 50% after 256 training steps, otherwise select 100% of the cells
			const float cell_selection_threshold = i > 256 ? 0.5f : 1.0f;
			trainer.update_occupancy_grid(stream, cell_selection_threshold);
		}
		// if indices_vector contains the number i, then render

		if (i % 256 == 0 && i > 0) {
			float progress = 0.0f;
			float tau = 2.0f * 3.14159f;
			auto tform = nrc::Matrix4f::Rotation(progress * tau, 0.0f, 1.0f, 0.0f) * cam0.transform;
			auto render_cam = nrc::Camera(
				cam0.near,
				cam0.far,
				cam0.focal_length,
				make_int2(1024, 1024),
				cam0.sensor_size,
				tform
			);

			auto render_request = nrc::RenderRequest(render_buffer, render_cam, nerf_ptrs);
			render_request.output.clear(stream);
			renderer.request_render(stream, render_request);
			render_request.output.save_image(stream, OUTPUT_PATH + fmt::format("img-{}.png", i));
		}
	}

	// Wait for the kernel to finish executing
	cudaDeviceSynchronize();
	return 0;
}
