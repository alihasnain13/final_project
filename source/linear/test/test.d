/// This library attempts to emulate the same
/// glsl datatypes and functions.
module test;
import linear;

import std.stdio;


/// Example of matrix identity 1
unittest{
    writeln("====== Matrix Identity 1 =====");
    mat4 mat1;
    mat4 mat2 = mat4(1.0f);

    MatrixDebugPrint("mat1", mat1, "mat2", mat2);


    writeln("---------------------------------");
}
/// Example of matrix identity 2
unittest{
    writeln("====== Matrix Identity 2 =====");
    mat4 mat1;
    mat4 mat2 = mat4(1);

    MatrixDebugPrint("mat1", mat1, "mat2", mat2);

    writeln("---------------------------------");
}

/// Some of the basic types can be used with their
/// multiple constructors in creative ways to
/// otherwise build a matrix or vector.
unittest{
    writeln("=========== World space ========");
    vec4 position = vec4(vec3(1.0f,2.0f,3.0f),1.0f);
    mat4 modelMatrix = mat4(1.0f);
//    modelMatrix[3] = vec4(1.0,1.0,1.0,1.0);
    writeln(modelMatrix);

    writeln;
    vec4 worldSpace = modelMatrix*position;
    writeln(worldSpace);
    writeln("---------------------------------");
}

/// Matrix construction can be done by specifying
/// either the single diagonal value, or by using
/// 4 column vectors.
unittest{
    writeln("====== Matrix Constructors =====");
    mat4 matrix1 = mat4(3.0f);

    mat4 matrix2 = mat4(matrix1.Col(0),
                        matrix1.Col(1),
                        matrix1.Col(2),
                        matrix1.Col(3));

    MatrixDebugPrint("matrix1",matrix1,"matrix2",matrix2);

    assert(matrix1 == matrix2, "equivalent matrices"); 

    writeln("---------------------------------");
}

/// Example of matrix multiplication
unittest{
    writeln("========= Matrix Mutiply ========");

		mat4 m1 = mat4(1,0,2,0,
               		 0,3,0,4,
							 		 0,0,5,0,
							 		 6,0,0,7);
		mat4 m2 = mat4(1,2,3,4,
									 5,6,7,8,
									 9,10,11,12,
									 13,14,15,16);

		vec4 v1 = vec4(2,5,1,8);

		assert(m1*v1 == vec4(4,47,5,68), "mat4 * vec4 passed");
		writeln(m1*m2);
		assert(m1*m2 == mat4(19,22,25,28,67,74,81,88,45,50,55,60,97,110,123,136), "mat4 * mat4 passed");

    writeln("---------------------------------");
}

/// Example of matrix translation 
/// Check with: https://www.wolframalpha.com/input?i=matrix+multiplication+calculator
unittest{
    writeln("====== Matrix Translation =====");
    vec4 position  = vec4(vec3(1.0),1.0f);
    mat4 translate = MatrixMakeTranslation(vec3(4.0f,3.0f,1.0f));

    vec4 worldSpace = translate * position;

    MatrixVectorDebugPrint("translate",translate,"position",position);
    VectorDebugPrint("before",position,"after",worldSpace);

    writeln("---------------------------------");
}

/// Example of matrix scale
/// Check with: https://www.wolframalpha.com/input?i=matrix+multiplication+calculator
unittest{
    writeln("====== Matrix Scale =====");
    vec4 position   = vec4(vec3(1.0,2.0,3.0),1.0f);
    mat4 scale      = MatrixMakeScale(vec3(2.0f,3.0f,4.0f));

    vec4 worldSpace = scale * position;

    MatrixVectorDebugPrint("scale",scale,"position",position);
    VectorDebugPrint("before",position,"after",worldSpace);

    writeln("---------------------------------");
}

/// Example of matrix X rotation
/// Check with: https://www.wolframalpha.com/input?i=matrix+multiplication+calculator
unittest{
    writeln("====== Matrix X Rotation=====");
    vec4 position   = vec4(vec3(1.0,2.0,3.0),1.0f);
    mat4 rotX       = MatrixMakeXRotation(90.ToRadians);


    vec4 worldSpace = rotX * position;

    MatrixVectorDebugPrint("rotX",rotX,"position",position);
    VectorDebugPrint("before",position,"after",worldSpace);

    writeln("---------------------------------");
}

/// Example of matrix Y rotation
/// Check with: https://www.wolframalpha.com/input?i=matrix+multiplication+calculator
unittest{
    writeln("====== Matrix Y Rotation=====");
    vec4 position   = vec4(vec3(1.0,2.0,3.0),1.0f);
    mat4 rotY       = MatrixMakeYRotation(90.ToRadians);


    vec4 worldSpace = rotY * position;

    MatrixVectorDebugPrint("rotY",rotY,"position",position);
    VectorDebugPrint("before",position,"after",worldSpace);

    writeln("---------------------------------");
}

/// Example of matrix Z rotation
/// Check with: https://www.wolframalpha.com/input?i=matrix+multiplication+calculator
unittest{
    writeln("====== Matrix Z Rotation=====");
    vec4 position   = vec4(vec3(1.0,2.0,3.0),1.0f);
    mat4 rotZ       = MatrixMakeZRotation(90.ToRadians);


    vec4 worldSpace = rotZ * position;

    MatrixVectorDebugPrint("rotZ",rotZ,"position",position);
    VectorDebugPrint("before",position,"after",worldSpace);

    writeln("---------------------------------");
}

/// Example of retrieving values from a matrix or vector
/// This can be useful for otherwise for passing the vector or matrix
/// into uniform.
unittest{
    writeln("=========== Data Pointers ======");
    vec2 v2;
    vec3 v3;
    vec4 v4;
    mat4 m4;

    writeln("Data:",v2.Data," at address: ",v2.DataPtr());
    writeln("Data:",v3.Data," at address: ",v3.DataPtr());
    writeln("Data:",v4.Data," at address: ",v4.DataPtr());
    writeln("Data:",m4.Data," at address: ",m4.DataPtr());

    writeln("---------------------------------");
}


/// Example of accessing matrix
unittest{
    writeln("=========== Matrix access ======");
    mat4 m4 = mat4(1,2,3,4,
                   5,6,7,8,
                   9,10,11,12,
                   13,14,15,16);
    writeln("Given this matrix:");
    writeln(m4,"\n");

    writeln("element at zero-position:",m4[0]);
    writeln("First column:",m4.Col(0));
    writeln("First row:",m4.Row(0));
    writeln;

    writeln("element at second position:",m4[1]);
    writeln("Second column:",m4.Col(1));
    writeln("Second row:",m4.Row(1));
    writeln;

    writefln("m4[0,0]=%f  == m[0]=%f",m4[0,0],m4[0]);
    writefln("m4[1,0]=%f  == m[4]=%f",m4[1,0],m4[4]);
    writefln("m4[1,1]=%f  == m[5]=%f",m4[1,1],m4[5]);
    writefln("m4[1,2]=%f  == m[6]=%f",m4[1,2],m4[6]);

    writeln("Given 0th row = index 1, 1st row = index 2, etc.");
    writeln("Third Row, first element: ",m4[2,0]);
    writeln("Third Row, first element: ",m4.Row(2).x);
    writeln("Third Col, second element: ",m4[1,2]);
    writeln("Third Col, second element: ",m4.Col(2)[1]);

    writeln("---------------------------------");
}


