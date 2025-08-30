# _plugins/canvas_converter.rb
require 'json'

module Jekyll
  class CanvasConverter < Converter
    safe true
    priority :low

    def matches(ext)
      ext =~ /^\.canvas$/i
    end

    def output_ext(ext)
      ".html"
    end

    def convert(content)
      begin
        canvas_data = JSON.parse(content)
        render_canvas_html(canvas_data)
      rescue JSON::ParserError => e
        "<div class='error'>Error parsing canvas file: #{e.message}</div>"
      end
    end

    private

    def render_canvas_html(canvas_data)
      nodes = canvas_data['nodes'] || []
      edges = canvas_data['edges'] || []
      
      # Calculate canvas bounds
      bounds = calculate_bounds(nodes)
      
      html = <<~HTML
        <div class="canvas-container" style="position: relative; width: 100%; height: #{bounds[:height] + 100}px; border: 1px solid #ddd; background: #fafafa; overflow: auto;">
          #{render_nodes(nodes)}
          #{render_edges(edges, nodes)}
        </div>
        <style>
          .canvas-container {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          }
          .canvas-node {
            position: absolute;
            border: 2px solid #ccc;
            border-radius: 8px;
            background: white;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            padding: 12px;
            min-width: 100px;
            word-wrap: break-word;
          }
          .canvas-node.file {
            border-color: #4a90e2;
            background: #f8fbff;
          }
          .canvas-node.text {
            border-color: #7ed321;
            background: #f8fff8;
          }
          .canvas-node.group {
            border-color: #f5a623;
            background: #fffcf8;
            border-style: dashed;
          }
          .canvas-node.link {
            border-color: #d0021b;
            background: #fff8f8;
          }
          .canvas-node h1, .canvas-node h2, .canvas-node h3, 
          .canvas-node h4, .canvas-node h5, .canvas-node h6 {
            margin-top: 0;
            margin-bottom: 8px;
          }
          .canvas-edge {
            position: absolute;
            pointer-events: none;
            z-index: 1;
          }
          .canvas-edge-line {
            stroke: #666;
            stroke-width: 2;
            fill: none;
            marker-end: url(#arrowhead);
          }
          .canvas-edge-arrow {
            stroke: #666;
            fill: #666;
          }
        </style>
        <svg width="0" height="0" style="position: absolute;">
          <defs>
            <marker id="arrowhead" markerWidth="10" markerHeight="7" 
                    refX="9" refY="3.5" orient="auto">
              <polygon points="0 0, 10 3.5, 0 7" class="canvas-edge-arrow" />
            </marker>
          </defs>
        </svg>
      HTML
    end

    def calculate_bounds(nodes)
      return { width: 800, height: 600 } if nodes.empty?
      
      min_x = nodes.map { |n| n['x'] }.min
      max_x = nodes.map { |n| n['x'] + (n['width'] || 200) }.max
      min_y = nodes.map { |n| n['y'] }.min
      max_y = nodes.map { |n| n['y'] + (n['height'] || 100) }.max
      
      {
        width: [max_x - min_x, 800].max,
        height: [max_y - min_y, 600].max,
        min_x: min_x,
        min_y: min_y
      }
    end

    def render_nodes(nodes)
      nodes.map do |node|
        render_node(node)
      end.join("\n")
    end

    def render_node(node)
      x = node['x'] || 0
      y = node['y'] || 0
      width = node['width'] || 200
      height = node['height'] || 100
      
      content = render_node_content(node)
      node_type = node['type'] || 'text'
      
      <<~HTML
        <div class="canvas-node #{node_type}" 
             style="left: #{x}px; top: #{y}px; width: #{width}px; min-height: #{height}px;"
             data-node-id="#{node['id']}">
          #{content}
        </div>
      HTML
    end

    def render_node_content(node)
      case node['type']
      when 'file'
        file_path = node['file'] || ''
        file_name = File.basename(file_path, '.*')
        "<strong>📄 #{file_name}</strong><br><small>#{file_path}</small>"
      when 'text'
        text_content = node['text'] || ''
        converted = convert_basic_markdown(text_content)
        converted
      when 'group'
        label = node['label'] || 'Group'
        "<h3>#{label}</h3>"
      when 'link'
        url = node['url'] || '#'
        "<a href='#{url}' target='_blank'>🔗 #{url}</a>"
      else
        node['text'] || node['label'] || 'Unknown node type'
      end
    end

    def convert_basic_markdown(text)
      text = text.gsub(/^# (.+)$/, '<h1>\1</h1>')
      text = text.gsub(/^## (.+)$/, '<h2>\1</h2>')
      text = text.gsub(/^### (.+)$/, '<h3>\1</h3>')
      text = text.gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>')
      text = text.gsub(/\*(.+?)\*/, '<em>\1</em>')
      text = text.gsub(/\[(.+?)\]\((.+?)\)/, '<a href="\2">\1</a>')
      text = text.gsub(/\n/, '<br>')
      text
    end

    def render_edges(edges, nodes)
      return "" if edges.empty?
      
      node_lookup = nodes.each_with_object({}) { |node, hash| hash[node['id']] = node }
      
      svg_elements = edges.map do |edge|
        render_edge(edge, node_lookup)
      end.compact.join("\n")
      
      return "" if svg_elements.empty?
      
      bounds = calculate_bounds(nodes)
      
      <<~HTML
        <svg class="canvas-edge" style="width: 100%; height: 100%; position: absolute; top: 0; left: 0;">
          #{svg_elements}
        </svg>
      HTML
    end

    def render_edge(edge, node_lookup)
      from_node = node_lookup[edge['fromNode']]
      to_node = node_lookup[edge['toNode']]
      
      return nil unless from_node && to_node
      
      from_side = edge['fromSide'] || 'right'
      to_side = edge['toSide'] || 'left'
      
      from_point = calculate_connection_point(from_node, from_side)
      to_point = calculate_connection_point(to_node, to_side)
      
      # Create a curved path
      control_offset = 50
      control1_x = from_point[:x] + (from_side == 'right' ? control_offset : -control_offset)
      control1_y = from_point[:y]
      control2_x = to_point[:x] + (to_side == 'left' ? -control_offset : control_offset)
      control2_y = to_point[:y]
      
      path_data = "M #{from_point[:x]} #{from_point[:y]} C #{control1_x} #{control1_y}, #{control2_x} #{control2_y}, #{to_point[:x]} #{to_point[:y]}"
      
      "<path d=\"#{path_data}\" class=\"canvas-edge-line\" />"
    end

    def calculate_connection_point(node, side)
      x = node['x'] || 0
      y = node['y'] || 0
      width = node['width'] || 200
      height = node['height'] || 100
      
      case side
      when 'top'
        { x: x + width / 2, y: y }
      when 'bottom'
        { x: x + width / 2, y: y + height }
      when 'left'
        { x: x, y: y + height / 2 }
      when 'right'
        { x: x + width, y: y + height / 2 }
      else
        { x: x + width / 2, y: y + height / 2 }
      end
    end
  end
end