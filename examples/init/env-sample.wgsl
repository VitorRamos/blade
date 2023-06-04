var env_weights: texture_2d<f32>;
var sampler_nearest: sampler;

struct RandomState {
    seed: u32,
    index: u32,
}

// 32 bit Jenkins hash
fn hash_jenkins(value: u32) -> u32 {
    var a = value;
    // http://burtleburtle.net/bob/hash/integer.html
    a = (a + 0x7ed55d16u) + (a << 12u);
    a = (a ^ 0xc761c23cu) ^ (a >> 19u);
    a = (a + 0x165667b1u) + (a << 5u);
    a = (a + 0xd3a2646cu) ^ (a << 9u);
    a = (a + 0xfd7046c5u) + (a << 3u);
    a = (a ^ 0xb55a4f09u) ^ (a >> 16u);
    return a;
}

fn random_init(pixel_index: u32, frame_index: u32) -> RandomState {
    var rs: RandomState;
    rs.seed = hash_jenkins(pixel_index) + frame_index;
    rs.index = 0u;
    return rs;
}

fn rot32(x: u32, bits: u32) -> u32 {
    return (x << bits) | (x >> (32u - bits));
}

// https://en.wikipedia.org/wiki/MurmurHash
fn murmur3(rng: ptr<function, RandomState>) -> u32 {
    let c1 = 0xcc9e2d51u;
    let c2 = 0x1b873593u;
    let r1 = 15u;
    let r2 = 13u;
    let m = 5u;
    let n = 0xe6546b64u;

    var hash = (*rng).seed;
    (*rng).index += 1u;
    var k = (*rng).index;
    k *= c1;
    k = rot32(k, r1);
    k *= c2;

    hash ^= k;
    hash = rot32(hash, r2) * m + n;

    hash ^= 4u;
    hash ^= (hash >> 16u);
    hash *= 0x85ebca6bu;
    hash ^= (hash >> 13u);
    hash *= 0xc2b2ae35u;
    hash ^= (hash >> 16u);

    return hash;
}

fn random_gen(rng: ptr<function, RandomState>) -> f32 {
    let v = murmur3(rng);
    let one = bitcast<u32>(1.0);
    let mask = (1u << 23u) - 1u;
    return bitcast<f32>((mask & v) | one) - 1.0;
}

@vertex
fn vs_accum(@builtin(vertex_index) vi: u32) -> @builtin(position) vec4<f32> {
    var rng = random_init(vi, 0u);
    var mip = i32(textureNumLevels(env_weights));
    var itc = vec2<i32>(0);
    // descend through the mip chain to find a concrete pixel
    while (mip != 0) {
        mip -= 1;
        let weights = textureLoad(env_weights, itc, mip);
        let sum = dot(vec4<f32>(1.0), weights);
        let r = random_gen(&rng) * sum;
        itc *= 2;
        if (r >= weights.x+weights.y) {
            itc.y += 1;
            itc.x += step(weights.x+weights.y+weights.z, r);
        } else {
            itc.x += step(weights.x, r);
        }
    }

    let extent = textureDimensions(env_weights, 0);
    let relative = (vec2<f32>(itc) + vec2<f32>(0.5)) / vec2<f32>(extent);
    return vec4<f32>(relative.x - 1.0, 1.0 - relative.y, 0.0, 1.0);
}

@fragment
fn fs_accum() -> @location(0) vec4<f32> {
    return vec4<f32>(1.0, 0.0, 0.0, 0.0);
}
