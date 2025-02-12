#version 460

layout(set=1,binding=0) uniform UBO {
    mat4 mvp;
    int size;
    float step;
};

void main() {
    float halfSize = float(step * size) / 2;
    int rowInstanceStart = size + 1;
    int isCol = gl_InstanceIndex / rowInstanceStart; // 0 for cols, 1 for rows
    int index = gl_InstanceIndex % rowInstanceStart; // index of row OR col
    float a = -halfSize + index * step; // stepping
    float b = mix(-halfSize, halfSize, gl_VertexIndex); // start or end
    vec2 pos = mix(vec2(a,b), vec2(b,a), isCol);
    gl_Position = mvp * vec4(pos.x, 0, pos.y, 1);
}