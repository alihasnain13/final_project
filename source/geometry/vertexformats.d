/// Stores various useful vertex formats for arranging data
module vertexformats;

/// A struct representing x,y,z and r,g,b
struct VertexFormat3F3F{
	float[3] aPosition;
	float[3] aColor;
}

/// A struct representing for x,y,z and s,t
struct VertexFormat3F2F{
	float[3] aPostition;
	float[2] aTextureCoord;
}

/// A struct representing for x,y,z, nx,ny,nz, and s,t
struct VertexFormat3F3F2F{
	float[3] aPostition;
	float[3] aNormal;
	float[2] aTextureCoord;
}

/// A struct representing for x,y,z, nx,ny,nz, bnx,bny,bnz, tnx,tny,tnz, and s,t
struct VertexFormat3F3F2F3F3F{
	float[3] aPostition;
	float[3] aNormal;
	float[2] aTextureCoord;
	float[3] aBiNormal;
	float[3] aBiTangent;
}
