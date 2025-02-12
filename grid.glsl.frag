#version 460

layout(set=3,binding=0) uniform UBO {
    vec4 color;
};

layout(location=0) out vec4 frag_color;

void main() {
    frag_color = color;
}