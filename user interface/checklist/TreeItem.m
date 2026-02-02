classdef TreeItem < handle
    %TreeNode  A simple node class for hierarchical data (tree).
    %
    % Properties
    %   Text      - display name (string)
    %   Data      - any payload attached to this node
    %   Children  - 1xN TreeNode array
    %
    % Usage
    %   % init node tree
    %   root = TreeItem("Root");
    %   a = root.addChild("A", []);
    %   a.addChild("A1", 123);
    %   a.addChild("A2", 456);
    %   root.addChild("B", "hello");
    %   % create checklist app
    %   ckl = checklist(root);
    %   uiwait(ckl.UIFigure, 20);
    %   disp({ckl.selectedData.Data}); % TODO: processing
    %   delete(ckl);

    properties
        Text (1,1) string = ""
        Data = []
        Children (1,:) TreeItem = TreeItem.empty(1, 0)
    end

    methods
        function obj = TreeItem(text, data)
            if nargin >= 1 && ~isempty(text)
                obj.Text = string(text);
            end
            if nargin >= 2
                obj.Data = data;
            end
        end

        function child = addChild(obj, text, data)
            % addChild  Create a child node and append it.
            if nargin < 2, text = ""; end
            if nargin < 3, data = []; end
            child = TreeItem(text, data);
            obj.Children(end + 1) = child;
        end

        function setChildren(obj, children)
            % setChildren  Replace children with a TreeNode array.
            arguments
                obj      (1,1) TreeItem
                children (1,:) TreeItem
            end
            obj.Children = children;
        end

        function tf = isLeaf(obj)
            tf = isempty(obj.Children);
        end

        function n = numChildren(obj)
            n = numel(obj.Children);
        end
    end
end
