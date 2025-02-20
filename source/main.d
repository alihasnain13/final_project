module main;

import engine.application;

/// Program entry point 
/// NOTE: When debugging, this is '_Dmain'
void main(string[] args)
{
    GraphicsApp app = GraphicsApp(640, 480, args);
    app.Loop();
}
