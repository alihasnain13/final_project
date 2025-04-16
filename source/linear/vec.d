/// This module contains several vec data types.
module vec;

import std.stdio, std.math, std.conv;

/// Vector with 2-dimensions
struct vec2{
		union{
				struct{
						float x=0.0f;
						float y=0.0f;
				}
				struct{
						float[2] data;
				}
		}
		/// Constructor for a vec2 type
		/// Repeats every value
		this(float value){
				this.x = value;
				this.y = value;
		}
		/// Constructor for a vec2 type
		this(float x, float y){
				this.x = x;
				this.y = y;
		}
		/// Retrieve data as a float array
		float[2] Data(){
				return this.data;
		}
		/// Retrieve pointer to raw data
		float* DataPtr(){
				return this.data.ptr;
		}
		float opIndex(size_t i){
				return data[i];
		}
		void opAssign(vec2 v){
				data = v.data;
		}
		void opIndexAssign(float value,size_t i){
				data[i] = value;
		}

		/// opUnary for negation operations
		vec2 opUnary(string op)(){
			vec2 result;
			static if(op=="-"){
						result.x = -this.x;
						result.y = -this.y;
			}
			return result;
		}

		/// opBinary operations with vectors
		vec2 opBinary(string op)(vec2 v){
				vec2 result;
				static if(op=="+"){
						result.x = this.x + v.x;
						result.y = this.y + v.y;
				}
				static if(op=="-"){
						result.x = this.x - v.x;
						result.y = this.y - v.y;
				}
				return result;
		}

		/// opBinary operations with scalar values.
		vec2 opBinary(string op)(float f){
				vec2 result;
				static if(op=="*"){
						result.x = this.x * f;
						result.y = this.y * f;
				}
				static if(op=="/"){
						result.x = this.x / f;
						result.y = this.y / f;
				}
				return result;
		}
		/// Built-in to retrieve vector in 'writeln'
		/// e.g. writeln(vec2(1.0f,1.0f));
		string toString(){
				return "<"~x.to!string~","~y.to!string~">";
		}
}

/// Vector with 3-dimensions
struct vec3{
		union{
				struct{
						float x=0.0f;
						float y=0.0f;
						float z=0.0f;
				}
				struct{
						float[3] data;
				}
		}
		/// Constructor for a vec3 type
		/// Repeats every value
		this(float value){
				this.x = value;
				this.y = value;
				this.z = value;
		}
		/// Constructor for a vec3 type
		this(vec2 v, float z){
				this.x = v.x;
				this.y = v.y;
				this.z = z;
		}
		/// Constructor for a vec3 type
		this(float x, float y, float z){
				this.x = x;
				this.y = y;
				this.z = z;
		}
		/// Retrieve floating point data
		float[3] Data(){
				return this.data;
		}
		/// Retrieve pointer to underlying data
		float* DataPtr(){
				return this.data.ptr;
		}
		/// Retrieve individual data 
		float opIndex(size_t i){
				return data[i];
		}
		void opAssign(vec3 v){
				data = v.data;
		}
		/// Assign new value to index
		void opIndexAssign(float value,size_t i){
				data[i] = value;
		}

		/// opUnary for negation operations
		vec3 opUnary(string op)(){
			vec3 result;
			static if(op=="-"){
						result.x = -this.x;
						result.y = -this.y;
						result.z = -this.z;
			}
			return result;
		}

		/// Binary operations on a vector
		vec3 opBinary(string op)(vec3 v){
				vec3 result;
				static if(op=="+"){
						result.x = this.x + v.x;
						result.y = this.y + v.y;
						result.z = this.z + v.z;
				}
				static if(op=="-"){
						result.x = this.x - v.x;
						result.y = this.y - v.y;
						result.z = this.z - v.z;
				}
				return result;
		}

		/// Scalar operations on a vector
		vec3 opBinary(string op)(float f){
				vec3 result;
				static if(op=="*"){
						result.x = this.x * f;
						result.y = this.y * f;
						result.z = this.z * f;
				}
				static if(op=="/"){
						result.x = this.x / f;
						result.y = this.y / f;
						result.z = this.z / f;
				}
				return result;
		}
		/// Built-in to retrieve vector in 'writeln'
		/// e.g. writeln(vec3(1.0f,1.0f,1.0f));
		string toString(){
				return "<"~x.to!string~","~y.to!string~","~z.to!string~">";
		}
}

/// Vector with 4-dimensions
struct vec4{
		/// Union structure is used so that you can access the data using
		/// two 'different' ways.
		union{
				struct{
						float x=0.0f;
						float y=0.0f;
						float z=0.0f;
						float w=0.0f;
				}
				struct{
						float[4] data;
				}
		}

		/// Constructor for a vec4 type
		/// Repeats every value
		this(float value){
				this.x = value;
				this.y = value;
				this.z = value;
				this.w = value;
		}

		/// Constructor for a vec4 type
		this(vec2 v, float z, float w){
				this.x = v.x;
				this.y = v.y;
				this.z = z;
				this.w = w;
		}
		/// Constructor for a vec4 type
		this(vec3 v, float w){
				this.x = v.x;
				this.y = v.y;
				this.z = v.z;
				this.w = w;
		}
		/// Constructor for a vec4 type
		this(float x, float y, float z, float w){
				this.x = x;
				this.y = y;
				this.z = z;
				this.w = w;
		}

		/// Retrieve the static array for data values
		float[4] Data(){
				return this.data;
		}

		/// Retrieve the static array for data
		float* DataPtr(){
				return this.data.ptr;
		}

		float opIndex(size_t i){
				return data[i];
		}
		void opAssign(vec4 v){
				data = v.data;
		}
		void opIndexAssign(float value,size_t i){
				data[i] = value;
		}

		/// opUnary for negation operations
		vec4 opUnary(string op)(){
			vec4 result;
			static if(op=="-"){
						result.x = -this.x;
						result.y = -this.y;
						result.z = -this.z;
						result.w = -this.w;
			}
			return result;
		}

		/// opBinary operations with vectors
		vec4 opBinary(string op)(vec4 v){
				vec4 result;
				static if(op=="+"){
						result.x = this.x + v.x;
						result.y = this.y + v.y;
						result.z = this.z + v.z;
						result.w = this.w + v.w;
				}
				static if(op=="-"){
						result.x = this.x - v.x;
						result.y = this.y - v.y;
						result.z = this.z - v.z;
						result.w = this.w - v.w;
				}
				return result;
		}

		/// opBinary operations with scalar values.
		vec4 opBinary(string op)(float f){
				vec4 result;
				static if(op=="*"){
						result.x = this.x * f;
						result.y = this.y * f;
						result.z = this.z * f;
						result.w = this.w * f;
				}
				static if(op=="/"){
						result.x = this.x / f;
						result.y = this.y / f;
						result.z = this.z / f;
						result.w = this.w / f;
				}
				return result;
		}

		/// Optional to implement
		/*
		/// Handle various layouts for accessing variables.
		/// Note: You can use various 'accessors'
		///       and can consider the 'permutation' library to otherwise
		///       generate all possible combinations at compile-time.
		float opDispatch(string name)(){
		if(name =="r") {	return x;               }
		assert(0);
		}
		vec2 opDispatch(string name)(){
		if(name == "rg")    {	return vec2(x,y);	    }
		assert(0);
		}
		vec3 opDispatch(string name)(){
		if(name == "rgb")   {   return vec3(x,y,z);	    }
		assert(0);
		}
		vec4 opDispatch(string name)(){
		if(name == "rgba")  {	return vec4(x,y,z,w);	}
		}
		 */

		/// Special function in D to work with 'writeln' for example.
		/// This is the function that will be called to write the vector as a string.
		/// NOTE: Writing this function can be improved using interpolated string sequences
		///       if you are using a later version of D.
		/// e.g. writeln(vec4(1.0f,1.0f,1.0f,1.0f));
		string toString(){
				return "<"~x.to!string~","~y.to!string~","~z.to!string~","~w.to!string~">";
		}
}

/// Helper function that will print two vectors side by side
void VectorDebugPrint(string name1, vec4 v1, string name2, vec4 v2){
		writeln(name1,"\t\t",name2);
		writeln(v1,"\t",v2);
}

/// Return the Magnitude of a vector
float Magnitude(vec2 v){
		return sqrt(v.x*v.x + v.y*v.y);
}
/// Return the Magnitude of a vector
float Magnitude(vec3 v){
		return sqrt(v.x*v.x + v.y*v.y + v.z*v.z);
}

/// Return the Magnitude of a vector
float Magnitude(vec4 v){
		if(v.w  != 0.0f){
				writeln("WARNING: May be illegally computing the length of a point");
		}
		return sqrt(v.x*v.x + v.y*v.y + v.z*v.z + v.w*v.w);
}

/// Returns a unit vector
vec2 Normalize(vec2 v){
		float length = Magnitude(v);
		if(length == 0.0f){
				writeln("WARNING: retrieved a zero value for magnitude");
				return vec2(0.0f,0.0f);
		}
		float length_reciprocal = 1.0f / length;

		return vec2(v.x * length_reciprocal, v.y *length_reciprocal); 
}

/// Returns a unit vector
vec3 Normalize(vec3 v){
		float length = v.Magnitude();
		if(length == 0.0f){
				writeln("WARNING: retrieved a zero value for magnitude");
				return vec3(0.0f,0.0f,0.0f);
		}
		float length_reciprocal = 1.0f / length;

		return vec3(v.x * length_reciprocal, v.y *length_reciprocal, v.z * length_reciprocal); 
}

/// Returns a unit vector
vec4 Normalize(vec4 v){
		float length = v.Magnitude();
		if(length == 0.0f){
				writeln("WARNING: retrieved a zero value for magnitude");
				return vec4(0.0f,0.0f,0.0f,0.0f);
		}
		float length_reciprocal = 1.0f / length;

		return vec4(v.x * length_reciprocal, v.y *length_reciprocal, v.z * length_reciprocal, v.w*length_reciprocal); 
}



float Dot(vec2 a, vec2 b){
		return a.x*b.x + a.y*b.y;
}
float Dot(vec3 a, vec3 b){
		return a.x*b.x + a.y*b.y + a.z*b.z;
}
float Dot(vec4 a, vec4 b){
		if(a.w.isClose(1.0f) || b.w.isClose(1.0f)){
				//        writeln("Warning, may be operating on a point");
		}
		return a.x*b.x + a.y*b.y + a.z*b.z + a.w*b.w;
}

vec3 Cross(vec3 a, vec3 b){
		vec3 result;

		result[0] = a.y*b.z - b.y*a.z;
		result[1] = a.z*b.x - b.z*a.x;
		result[2] = a.x*b.y - b.x*a.y;

		return result;
}


float Distance(vec2 a, vec2 b){
		return sqrt((a.x - b.x)*(a.x-b.x) +
						(a.y - b.y)*(a.y-b.y));
}
float Distance(vec3 a, vec3 b){
		return sqrt((a.x - b.x)*(a.x-b.x) +
						(a.y - b.y)*(a.y-b.y) +
						(a.z - b.z)*(a.z-b.z));
}
float Distance(vec4 a, vec4 b){
		return sqrt((a.x - b.x)*(a.x-b.x) +
						(a.y - b.y)*(a.y-b.y) +
						(a.z - b.z)*(a.z-b.z) +
						(a.w - b.w)*(a.w-b.w));
}


//vec2 project(vec3


/// vec2 addition
unittest{
		vec2 v2a = vec2(1.0f,2.0f);
		vec2 v2b = vec2(1.0f,3.0f);
		assert(v2a+v2b == vec2(2.0f,5.0f), "vec2 addition check");
}
/// vec2 subtraction 
unittest{
		vec2 v2a = vec2(1.0f,2.0f);
		vec2 v2b = vec2(1.0f,3.0f);
		assert(v2a-v2b == vec2(0.0f,-1.0f), "vec2 subtraction check");
}
/// vec2 scalar multiplication
unittest{
		vec2 v2a = vec2(1.0f,2.0f);
		float k = 3.0f;
		assert(v2a * k == vec2(3.0f,6.0f), "vec2 scalar multiplication");
}
/// vec2 scalar division 
unittest{
		vec2 v2a = vec2(3.0f,6.0f);
		float k = 3.0f;
		assert(v2a / k == vec2(1.0f,2.0f), "vec2 scalar division");
}

/// vec3 addition
unittest{
		vec3 v3a = vec3(1.0f,2.0f,1.0f);
		vec3 v3b = vec3(1.0f,3.0f,2.0f);
		assert(v3a+v3b == vec3(2.0f,5.0f,3.0f), "vec3 addition check");
}
/// vec3 subtraction 
unittest{
		vec3 v3a = vec3(1.0f,2.0f,5.0f);
		vec3 v3b = vec3(1.0f,3.0f,2.0f);
		assert(v3a-v3b == vec3(0.0f,-1.0f,3.0f), "vec3 subtraction check");
}
/// vec3 scalar multiplication
unittest{
		vec3 v3a = vec3(1.0f,2.0f,-7.0);
		float k = 3.0f;
		assert(v3a * k == vec3(3.0f,6.0f,-21.0f), "vec3 scalar multiplication");
}
/// vec3 scalar division 
unittest{
		vec3 v3a = vec3(3.0f,6.0f,9.0);
		float k = 3.0f;
		assert(v3a / k == vec3(1.0f,2.0f,3.0f), "vec3 scalar division");
}

/// vec4 addition
unittest{
		vec4 v4a = vec4(1.0f,2.0f,1.0f,0.5f);
		vec4 v4b = vec4(1.0f,3.0f,2.0f,0.5f);
		assert(v4a+v4b == vec4(2.0f,5.0f,3.0f,1.0f), "vec4 addition check");
}
/// vec4 subtraction 
unittest{
		vec4 v4a = vec4(1.0f,2.0f,5.0f,0.2f);
		vec4 v4b = vec4(1.0f,3.0f,2.0f,0.2f);
		assert(v4a-v4b == vec4(0.0f,-1.0f,3.0f,0.0f), "vec4 subtraction check");
}
/// vec4 scalar multiplication
unittest{
		vec4 v4a = vec4(1.0f,2.0f,-7.0,3.0f);
		float k = 3.0f;
		assert(v4a * k == vec4(3.0f,6.0f,-21.0f,9.0f), "vec4 scalar multiplication");
}
/// vec4 scalar division 
unittest{
		vec4 v4a = vec4(3.0f,6.0f,9.0,3.0f);
		float k = 3.0f;
		assert(v4a / k == vec4(1.0f,2.0f,3.0f,1.0f), "vec4 scalar division");
}





/*
/// Demonstration of the 'swizzling technique' that can be used with 'opDispath' in D.
unittest{
vec2 v2 = vec2(1.0f,2.0f);
vec3 v3 = vec3(1.0f,2.0f,3.0f);
vec4 v4 = vec4(1.0f,2.0f,3.0f,4.0f);
assert(v4.xy() == v2, "swizzling works");
assert(v4.rg() == v2, "swizzling works");
assert(v4.xyz() == v3, "swizzling works");
assert(v4.rgb() == v3, "swizzling works");
}
 */

/// Demonstrating usage of magnitude.
/// Note: That we can use universal function call syntax to more nicely chain
///       together operations.
///       Generally speaking, I have tried to avoid 'member functions' within
///       math types for:
///       a.) compatibility with C
///       b.) keeps my code simpler, and easier to debug -- especially if we inline functions.
///       c.) Simpler structs for the math types
unittest{
		vec2 v2 = vec2(4.0f ,3.0f);
		vec3 v3 = vec3(0.0f, 0.0f, 5.0f);    
		vec4 v4 = vec4(2.0f, 6.0f, 3.0f, 0.0f );    

		assert(Magnitude(v2) == 5.0f); 
		assert(v2.Magnitude() == 5.0f);
		assert(v3.Magnitude() == 5.0f); 
		assert(v4.Magnitude() == 7.0f); 
}

/// Demonstration of normalizing a vector such that a unit vector is returned.
unittest{
		vec2 v2 = vec2(4.0f ,3.0f);
		vec3 v3 = vec3(1.0f, 2.0f, 3.0f);    
		vec4 v4 = vec4(1.0f, 2.0f, 3.0f, 0.0f );    

		assert(v2.Normalize.Magnitude.isClose(1.0f),"Expected 1.0f");
		assert(v3.Normalize.Magnitude.isClose(1.0f),"Expected 1.0f");
		assert(v4.Normalize.Magnitude.isClose(1.0f),"Exepcted 1.0f");
}

/// Demonstration of dot product
unittest{
		vec2 v2a = vec2(1.0f,2.0f);
		vec2 v2b = vec2(1.0f,3.0f);

		vec3 v3a = vec3(1.0f,2.0f,3.0f);
		vec3 v3b = vec3(2.0f,3.0f,4.0f);

		vec4 v4a = vec4(1.0f,2.0f,3.0f,4.0f);
		vec4 v4b = vec4(-1.0f,2.0f,3.0f,5.0f);

		assert(v2a.Dot(v2b) == 7.0f, "vec2 dot product check");
		assert(v3a.Dot(v3b) == 20.0f, "vec3 dot product check");
		assert(v4a.Dot(v4b) == 32.0f, "vec4 dot product check");
}

/// Calculator tests for cross product
/// https://www.wolframalpha.com/input?i=cross+product+calculator
unittest{
		vec3 v3a = vec3(1.0f,2.0f,3.0f);
		vec3 v3b = vec3(2.0f,3.0f,4.0f);

		assert(v3a.Cross(v3b) == vec3(-1.0f, 2.0f, -1.0f), "vec3 cross product test");
}

/// Distance calculations
unittest{
		vec2 v2a = vec2(1.0f,2.0f);
		vec2 v2b = vec2(1.0f,3.0f);

		vec3 v3a = vec3(5.0f,0.0f,0.0f);
		vec3 v3b = vec3(5.0f,-4.0f,0.0f);

		vec4 v4a = vec4(5.0f,0.0f,0.0f,3.0f);
		vec4 v4b = vec4(5.0f,-4.0f,0.0f,0.0f);

		assert(v2a.Distance(v2b) == 1.0f, "vec2 Distance check");
		assert(v3a.Distance(v3b) == 4.0f, "vec3 Distance check");
		assert(v4a.Distance(v4b) == 5.0f, "vec4 Distance check");
}


