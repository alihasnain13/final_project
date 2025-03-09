import graphics_app;

/// Program entry point 
/// NOTE: When debugging, this is '_Dmain'
void main(string[] args)
{
    GraphicsApp app = GraphicsApp(4,1);
    app.Loop();
}
