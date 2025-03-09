module scene;

import linear;
import camera;
import scene;

import std.range;
import std.stdio;

/// A Scene Tree is a data structure that stores all of the 'ISceneNode' types. 
/// It is traversed 
class SceneTree{
    ISceneNode mRootNode;
    // Camera
    Camera mCamera = null;

    /// Default constructor for creating a new Scene Tree
    this(string rootName){
        // Create the initial root node.
        // By default this is a 'GroupNode' which 
        // does not have anything other than
        // a name associated with it.
        mRootNode = new GroupNode(rootName);
    }

    /// Retrieve the root node
    ISceneNode GetRootNode(){
        return mRootNode;
    }

    /// Set the root node to another node.
    /// Useful if you want to only traverse a part of the sub-tree.
    void SetRootNode(ISceneNode newRootNode){
        mRootNode = newRootNode;
    }

    /// Set the camera that we will use for the scene tree traversal
    /// We also 'cache' the 'view' and 'projection' matrix
    void SetCamera(Camera camera){
        mCamera = camera;
    }

    /// Performs a traversal and returns the node if it exists
    ISceneNode FindNode(string name){
        if(name.length==0){
            assert(0,"Failure, cannot query for a node name of length 0");
        }
        // Test if root node is our query, otherwise we'll
        // proceed to perform DFS
        if(name == GetRootNode.mNodeName){
            return GetRootNode();
        }

        // Perform a depth-first traversal
        ISceneNode current = mRootNode;
        ISceneNode[] stack = current.mChildren;

        while(stack.length > 0){
            /// End of array (top of stack) is now current node.
            current = stack[$-1];
            if(current.mNodeName == name){
                return current;
            }
            // Remove the current node from stack
            stack.popBack();
            // Append all of the children to the back of the stack
            stack ~= current.mChildren;
        }

        writeln("Node '"~name~"' could not be found! in 'FindNode'.");
        return null;
    }

    /// Start the traversal of the scene tree
    void StartTraversal(){
        if(mCamera is null){
            assert(0,"Error: No camera attached to Scene tree for traversal, use SetCamera()");
        }

        
        foreach(child ; mRootNode.mChildren){
            child.Update();
        }


        /* TODO for students
        // Perform a depth-first traversal
        ISceneNode current = mRootNode;
        current.Update();
        ISceneNode[] stack = current.mChildren;

        while(stack.length > 0){
            /// End of array (top of stack) is now current node.
            current = stack[$-1];
            // Remove the current node from stack
            stack.popBack();
            // Perform update on current node
            current.Update();
            // Append all of the children to the back of the stack
            stack ~= current.mChildren;
        }
        */
    }

}

/// Everything in this abstraction is a 'node'
/// Every node has:
/// - A parent
/// - 0 or more children
/// - A friendly 'string name' representation of the node.
/// - A 'modelMatrix' for transformations
abstract class ISceneNode{
    ISceneNode   mParent = null;
    ISceneNode[] mChildren;
    mat4 mModelMatrix;	        // Transformation of our node
    string       mNodeName;     // Node Name -- useful for debugging

    /// Returns the parent scene node.
    /// If mParent is null, then this is either the 'root' node, or
    /// an invalid node
    ISceneNode GetParentSceneNode(){
        return mParent;
    }

    /// Adds a child node to the current Scene Node
    void AddChildSceneNode(ISceneNode node){
        node.mParent = this;
        this.mChildren ~= node;
    }

    /// Every node needs to implement an 'Update' function
    void Update();
}

/// A node for simply grouping entities together
class GroupNode : ISceneNode{
    this(){
    }
    /// Constructor for a Group Node to have a name
    this(string name){
        mNodeName = name;
    }

    override void Update(){
    }
}
