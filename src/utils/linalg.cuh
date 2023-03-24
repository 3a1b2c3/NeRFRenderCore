#pragma once

/**
 * Linear algebra helpers.
 * James Perlman, 2023 - much of this was generated by Copilot.
 * 
 * Eigen is not building with C++20, and there are some performance benefits to writing our own linear algebra helpers.
 * This is the bare minimum of what we need to run NeRF.
 * 
 */

#include <cuda_runtime.h>
#include <json/json.hpp>
#include "../common.h"

TURBO_NAMESPACE_BEGIN


inline NRC_HOST_DEVICE float lerp(const float &a, const float &b, const float &t)
{
    return a + (b - a) * t;
}


struct Matrix4f
{
    float m00, m01, m02, m03;
    float m10, m11, m12, m13;
    float m20, m21, m22, m23;
    float m30, m31, m32, m33;

    Matrix4f() = default;

    NRC_HOST_DEVICE Matrix4f(
        const float& m00, const float& m01, const float& m02, const float& m03,
        const float& m10, const float& m11, const float& m12, const float& m13,
        const float& m20, const float& m21, const float& m22, const float& m23,
        const float& m30, const float& m31, const float& m32, const float& m33
    ) : m00(m00), m01(m01), m02(m02), m03(m03),
        m10(m10), m11(m11), m12(m12), m13(m13),
        m20(m20), m21(m21), m22(m22), m23(m23),
        m30(m30), m31(m31), m32(m32), m33(m33)
    {};

    static Matrix4f Identity()
    {
        return Matrix4f{
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1
        };
    }

    // Generated by ChatGPT, creates a rotation matrix from an angle and an axis
    static Matrix4f Rotation(float angle, float x, float y, float z)
    {
        // angle is expected to be in radians
        float c = cosf(angle);
        float s = sinf(angle);

        return Matrix4f{
            x * x * (1 - c) + c,        y * x * (1 - c) + z * s,  x * z * (1 - c) - y * s,  0,
            x * y * (1 - c) - z * s,    y * y * (1 - c) + c,      y * z * (1 - c) + x * s,  0,
            x * z * (1 - c) + y * s,    y * z * (1 - c) - x * s,  z * z * (1 - c) + c,      0,
            0,                          0,                        0,                        1
        };
    }

    // create a translation matrix
    static Matrix4f Translation(const float& x, const float& y, const float& z)
    {
        return Matrix4f{
            1, 0, 0, x,
            0, 1, 0, y,
            0, 0, 1, z,
            0, 0, 0, 1
        };
    }

    // create a scale matrix
    static Matrix4f Scale(const float& x, const float& y, const float& z)
    {
        return Matrix4f{
            x, 0, 0, 0,
            0, y, 0, 0,
            0, 0, z, 0,
            0, 0, 0, 1
        };
    }

    static Matrix4f Scale(const float& s) {
        return Scale(s, s, s);
    }

    // efficient determinant for 4x4 transform matrix, where m30 = m31 = m32 = 0, m33 = 1
    float determinant() const
    {
        float det = m00 * (m11 * (m22 * m33 - m23 * m32) - m12 * (m21 * m33 - m23 * m31) + m13 * (m21 * m32 - m22 * m31)) -
                    m01 * (m10 * (m22 * m33 - m23 * m32) - m12 * (m20 * m33 - m23 * m30) + m13 * (m20 * m32 - m22 * m30)) +
                    m02 * (m10 * (m21 * m33 - m23 * m31) - m11 * (m20 * m33 - m23 * m30) + m13 * (m20 * m31 - m21 * m30)) -
                    m03 * (m10 * (m21 * m32 - m22 * m31) - m11 * (m20 * m32 - m22 * m30) + m12 * (m20 * m31 - m21 * m30));

        return det;
    }

    Matrix4f inverse() const
    {
        float det = determinant();

        return Matrix4f{
            +(m11 * (m22 * m33 - m23 * m32) - m12 * (m21 * m33 - m23 * m31) + m13 * (m21 * m32 - m22 * m31)) / det,
            -(m01 * (m22 * m33 - m23 * m32) - m02 * (m21 * m33 - m23 * m31) + m03 * (m21 * m32 - m22 * m31)) / det,
            +(m01 * (m12 * m33 - m13 * m32) - m02 * (m11 * m33 - m13 * m31) + m03 * (m11 * m32 - m12 * m31)) / det,
            -(m01 * (m12 * m23 - m13 * m22) - m02 * (m11 * m23 - m13 * m21) + m03 * (m11 * m22 - m12 * m21)) / det,
            -(m10 * (m22 * m33 - m23 * m32) - m12 * (m20 * m33 - m23 * m30) + m13 * (m20 * m32 - m22 * m30)) / det,
            +(m00 * (m22 * m33 - m23 * m32) - m02 * (m20 * m33 - m23 * m30) + m03 * (m20 * m32 - m22 * m30)) / det,
            -(m00 * (m12 * m33 - m13 * m32) - m02 * (m10 * m33 - m13 * m30) + m03 * (m10 * m32 - m12 * m30)) / det,
            +(m00 * (m12 * m23 - m13 * m22) - m02 * (m10 * m23 - m13 * m20) + m03 * (m10 * m22 - m12 * m20)) / det,
            +(m10 * (m21 * m33 - m23 * m31) - m11 * (m20 * m33 - m23 * m30) + m13 * (m20 * m31 - m21 * m30)) / det,
            -(m00 * (m21 * m33 - m23 * m31) - m01 * (m20 * m33 - m23 * m30) + m03 * (m20 * m31 - m21 * m30)) / det,
            +(m00 * (m11 * m33 - m13 * m31) - m01 * (m10 * m33 - m13 * m30) + m03 * (m10 * m31 - m11 * m30)) / det,
            -(m00 * (m11 * m23 - m13 * m21) - m01 * (m10 * m23 - m13 * m20) + m03 * (m10 * m21 - m11 * m20)) / det,
            -(m10 * (m21 * m32 - m22 * m31) - m11 * (m20 * m32 - m22 * m30) + m12 * (m20 * m31 - m21 * m30)) / det,
            +(m00 * (m21 * m32 - m22 * m31) - m01 * (m20 * m32 - m22 * m30) + m02 * (m20 * m31 - m21 * m30)) / det,
            -(m00 * (m11 * m32 - m12 * m31) - m01 * (m10 * m32 - m12 * m30) + m02 * (m10 * m31 - m11 * m30)) / det,
            +(m00 * (m11 * m22 - m12 * m21) - m01 * (m10 * m22 - m12 * m20) + m02 * (m10 * m21 - m11 * m20)) / det,
        };
    }


    // print matrix 
    void print() const
    {
        printf("%f %f %f %f\n", m00, m01, m02, m03);
        printf("%f %f %f %f\n", m10, m11, m12, m13);
        printf("%f %f %f %f\n", m20, m21, m22, m23);
        printf("%f %f %f %f\n", m30, m31, m32, m33);
        printf("\n");
    }

    // from_json constructor, mij = data[i][j]
    Matrix4f(const nlohmann::json& data)
    {
        m00 = data[0][0]; m01 = data[0][1]; m02 = data[0][2]; m03 = data[0][3];
        m10 = data[1][0]; m11 = data[1][1]; m12 = data[1][2]; m13 = data[1][3];
        m20 = data[2][0]; m21 = data[2][1]; m22 = data[2][2]; m23 = data[2][3];
        m30 = data[3][0]; m31 = data[3][1]; m32 = data[3][2]; m33 = data[3][3];
    }

    // multiplication operator with float3 - multiply by upper left 3x3, no translation
    inline NRC_HOST_DEVICE float3 mmul_ul3x3(const float3& v) const
    {
        return make_float3(
            m00 * v.x + m01 * v.y + m02 * v.z,
            m10 * v.x + m11 * v.y + m12 * v.z,
            m20 * v.x + m21 * v.y + m22 * v.z
        );
    }

    // multiplication operator with float3 - assume we want v to be inferred as homogeneous
    inline NRC_HOST_DEVICE float3 operator*(const float3& v) const
    {
        return make_float3(
            m00 * v.x + m01 * v.y + m02 * v.z + m03,
            m10 * v.x + m11 * v.y + m12 * v.z + m13,
            m20 * v.x + m21 * v.y + m22 * v.z + m23
        );
    }

    // multiplication operator with Matrix4f
    inline NRC_HOST_DEVICE Matrix4f operator*(const Matrix4f& x) const
    {
        return Matrix4f{
            m00 * x.m00 + m01 * x.m10 + m02 * x.m20 + m03 * x.m30,
            m00 * x.m01 + m01 * x.m11 + m02 * x.m21 + m03 * x.m31,
            m00 * x.m02 + m01 * x.m12 + m02 * x.m22 + m03 * x.m32,
            m00 * x.m03 + m01 * x.m13 + m02 * x.m23 + m03 * x.m33,

            m10 * x.m00 + m11 * x.m10 + m12 * x.m20 + m13 * x.m30,
            m10 * x.m01 + m11 * x.m11 + m12 * x.m21 + m13 * x.m31,
            m10 * x.m02 + m11 * x.m12 + m12 * x.m22 + m13 * x.m32,
            m10 * x.m03 + m11 * x.m13 + m12 * x.m23 + m13 * x.m33,

            m20 * x.m00 + m21 * x.m10 + m22 * x.m20 + m23 * x.m30,
            m20 * x.m01 + m21 * x.m11 + m22 * x.m21 + m23 * x.m31,
            m20 * x.m02 + m21 * x.m12 + m22 * x.m22 + m23 * x.m32,
            m20 * x.m03 + m21 * x.m13 + m22 * x.m23 + m23 * x.m33,

            m30 * x.m00 + m31 * x.m10 + m32 * x.m20 + m33 * x.m30,
            m30 * x.m01 + m31 * x.m11 + m32 * x.m21 + m33 * x.m31,
            m30 * x.m02 + m31 * x.m12 + m32 * x.m22 + m33 * x.m32,
            m30 * x.m03 + m31 * x.m13 + m32 * x.m23 + m33 * x.m33
        };
    }

    // multiplication between two 4x4 transform matrices.  It's assumed that the last line of each matrix is always 0 0 0 1.
    inline NRC_HOST_DEVICE Matrix4f mmul_fast_transform(const Matrix4f& x) const
    {
        return Matrix4f{
            m00 * x.m00 + m01 * x.m10 + m02 * x.m20,
            m00 * x.m01 + m01 * x.m11 + m02 * x.m21,
            m00 * x.m02 + m01 * x.m12 + m02 * x.m22,
            m00 * x.m03 + m01 * x.m13 + m02 * x.m23 + m03,

            m10 * x.m00 + m11 * x.m10 + m12 * x.m20,
            m10 * x.m01 + m11 * x.m11 + m12 * x.m21,
            m10 * x.m02 + m11 * x.m12 + m12 * x.m22,
            m10 * x.m03 + m11 * x.m13 + m12 * x.m23 + m13,

            m20 * x.m00 + m21 * x.m10 + m22 * x.m20,
            m20 * x.m01 + m21 * x.m11 + m22 * x.m21,
            m20 * x.m02 + m21 * x.m12 + m22 * x.m22,
            m20 * x.m03 + m21 * x.m13 + m22 * x.m23 + m23,

            0.0f,
            0.0f,
            0.0f,
            1.0f
        };
    }

    // convenience getter, returns the translation of this matrix as a float3
    inline NRC_HOST_DEVICE float3 get_translation() const
    {
        return make_float3(m03, m13, m23);
    }

    // linear interpolation between two matrices
    inline NRC_HOST_DEVICE Matrix4f lerp_to(const Matrix4f& x, const float& t)
    {
        return Matrix4f{
            lerp(m00, x.m00, t), lerp(m01, x.m01, t), lerp(m02, x.m02, t), lerp(m03, x.m03, t),
            lerp(m10, x.m10, t), lerp(m11, x.m11, t), lerp(m12, x.m12, t), lerp(m13, x.m13, t),
            lerp(m20, x.m20, t), lerp(m21, x.m21, t), lerp(m22, x.m22, t), lerp(m23, x.m23, t),
            lerp(m30, x.m30, t), lerp(m31, x.m31, t), lerp(m32, x.m32, t), lerp(m33, x.m33, t)
        };
    }
};

// multiplication float * float3
inline NRC_HOST_DEVICE float3 operator*(const float& s, const float3& v)
{
    return {s * v.x, s * v.y, s * v.z};
}

// division float3 / float
inline NRC_HOST_DEVICE float3 operator/(const float3& v, const float& s)
{
    return {v.x / s, v.y / s, v.z / s};
}

// addition float3 + float3
inline NRC_HOST_DEVICE float3 operator+(const float3& a, const float3& b)
{
    return {a.x + b.x, a.y + b.y, a.z + b.z};
}

// subtraction float3 - float3
inline NRC_HOST_DEVICE float3 operator-(const float3& a, const float3& b)
{
    return {a.x - b.x, a.y - b.y, a.z - b.z};
}

// l2 squared norm of a float3
inline NRC_HOST_DEVICE float l2_squared_norm(const float3& v)
{
    return v.x * v.x + v.y * v.y + v.z * v.z;
}

// l2 norm of a float3
inline NRC_HOST_DEVICE float l2_norm(const float3& v)
{
    return sqrtf(l2_squared_norm(v));
}

TURBO_NAMESPACE_END
