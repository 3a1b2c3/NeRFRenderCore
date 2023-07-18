#pragma once

#include <stbi/stb_image.h>
#include <tiny-cuda-nn/common.h>
#include <tiny-cuda-nn/common_device.h>
#include <tiny-cuda-nn/gpu_memory.h>

#include "../common.h"
#include "../core/occupancy-grid.cuh"
#include "../models/bounding-box.cuh"
#include "../models/camera.cuh"
#include "../models/ray.h"
#include "workspace.cuh"


TURBO_NAMESPACE_BEGIN

// NeRFWorkspace?
// TODO: Make this a derived struct from RenderingWorkspace
struct TrainingWorkspace: Workspace {

    using Workspace::Workspace;

    uint32_t batch_size;

    OccupancyGrid* occupancy_grid;

    float* random_float;


    // ground-truth pixel color components
    float* pix_rgba;

    // ray properties
    float* ray_rgba; // accumulated ray color

    uint32_t* ray_img_id; // used for appearance embedding
    uint32_t* ray_step;
    uint32_t* ray_offset;
    
    float* ray_origin;
    float* ray_dir;
    float* ray_t;
    float* ray_t_max;
    
    bool* ray_alive; // boolean value representing if the ray hits the bbox
    
    int* ray_index; // used for compaction while generating a training batch

    // normalized network input
    tcnn::network_precision_t* network_concat;
    tcnn::network_precision_t* network_output;

    // sample buffers
    int* sample_index; // indices of samples (for compaction)
    uint32_t* sample_img_id;
    float* sample_pos;
    float* sample_dir;
    float* sample_dt;
    float* sample_m_norm;
    float* sample_dt_norm;

    // primitives
    uint32_t n_samples_per_batch;

    // member functions
    void enlarge(
        const cudaStream_t& stream,
        const uint32_t& n_samples_per_batch,
        const uint32_t& n_occ_grid_levels,
        const uint32_t& n_occ_grid_cells_per_dimension,
        const size_t& n_network_concat_elements,
        const size_t& n_network_output_elements
    ) {
        free_allocations();

        this->n_samples_per_batch = n_samples_per_batch;
        
        batch_size = tcnn::next_multiple(n_samples_per_batch, tcnn::batch_size_granularity);

        // need to upgrade to C++20 to use typename parameters in lambdas :(
        // auto alloc = []<typename T>(size_t size) { return allocate<T>(stream, size); };

        occupancy_grid  = allocate<OccupancyGrid>(stream, 1);

        random_float    = allocate<float>(stream, 4 * batch_size);

        pix_rgba        = allocate<float>(stream, 4 * batch_size);
        ray_rgba        = allocate<float>(stream, 4 * batch_size);

        ray_img_id      = allocate<uint32_t>(stream, batch_size);
        ray_step        = allocate<uint32_t>(stream, batch_size);
        ray_offset      = allocate<uint32_t>(stream, batch_size);
        ray_origin      = allocate<float>(stream, 3 * batch_size);
        ray_dir         = allocate<float>(stream, 3 * batch_size);
        ray_t           = allocate<float>(stream, batch_size);
        ray_t_max       = allocate<float>(stream, batch_size);
        ray_alive       = allocate<bool>(stream, batch_size);
        ray_index       = allocate<int>(stream, batch_size);

        sample_index    = allocate<int>(stream, batch_size);
        sample_img_id   = allocate<uint32_t>(stream, batch_size);
        sample_pos      = allocate<float>(stream, 3 * batch_size);
        sample_dir      = allocate<float>(stream, 3 * batch_size);
        sample_dt       = allocate<float>(stream, batch_size);
        sample_m_norm   = allocate<float>(stream, batch_size);
        sample_dt_norm  = allocate<float>(stream, batch_size);

        network_concat  = allocate<tcnn::network_precision_t>(stream, n_network_concat_elements * batch_size);
        network_output  = allocate<tcnn::network_precision_t>(stream, n_network_output_elements * batch_size);
    }
};

TURBO_NAMESPACE_END
