/// Error handling support functions
module error;

import std.stdio;
import bindbc.opengl;


/// Clears the error state, but also reports on how many unhandled erros there may be at
/// any given time.
/// The number of errors may not necessarily be accurate, as one error state could cascade
/// to more error states, but your overall goal is to have '0' reported here.
int GLClearErrorStates(){
	// Return all of the errors that occur
	int count;
	while(glGetError()!=GL_NO_ERROR){
		count++;
	}
	return count;
}

/// 'F' is the call you want to make as a template argument
/// Note: __LINE__ is a special built-in to tell us the line number
bool GLCheckError(string F)(uint line=__LINE__){
	// Clear the errors here
	int errorCount = GLClearErrorStates();
	// Make our function call
	mixin(F);
	// Check if there was an error
	if(GLenum error = glGetError()){
		writeln("Error at ",line," :enum value of error is: ", error);
	}
	if(errorCount>0){
		writeln("There may be as many as ",errorCount," errors remaining");
	}
	return true;
}
