# frozen_string_literal: true

module IrtRuby
  # Finds the persons and items whose parameters are jointly estimable.
  # @api private
  module ResponseGraph
    module_function

    # Returns [persons, items] flags marking the parameters that have finite joint
    # maximum-likelihood estimates on a common scale. In the response graph a correct
    # answer links item -> person and an incorrect one person -> item; estimates exist
    # within a strongly connected component, so the largest one is kept. All-correct,
    # all-incorrect and unobserved rows or columns, perfectly separated subsets, and
    # subsets sharing no responses all fall outside it.
    def estimable(responses)
      num_persons = responses.size
      num_items = responses.first.size
      forward = Array.new(num_persons + num_items) { [] }
      backward = Array.new(num_persons + num_items) { [] }
      responses.each_with_index do |row, i|
        row.each_with_index do |value, j|
          next if value.nil?

          from, to = value == 1 ? [num_persons + j, i] : [i, num_persons + j]
          forward[from] << to
          backward[to] << from
        end
      end

      component = strongly_connected_components(forward, backward)
      sizes = Hash.new(0)
      component.each { |c| sizes[c] += 1 }
      largest, size = sizes.max_by { |c, n| [n, -c] }
      return [Array.new(num_persons, false), Array.new(num_items, false)] if size < 2

      [Array.new(num_persons) { |i| component[i] == largest },
       Array.new(num_items) { |j| component[num_persons + j] == largest }]
    end

    # Iterative Kosaraju: returns the component index of every node.
    def strongly_connected_components(forward, backward)
      order = []
      visited = Array.new(forward.size, false)
      forward.each_index do |start|
        next if visited[start]

        visited[start] = true
        stack = [[start, 0]]
        until stack.empty?
          node, edge = stack.last
          if edge < forward[node].size
            stack.last[1] += 1
            target = forward[node][edge]
            next if visited[target]

            visited[target] = true
            stack << [target, 0]
          else
            order << node
            stack.pop
          end
        end
      end

      component = Array.new(forward.size)
      count = 0
      order.reverse_each do |start|
        next if component[start]

        component[start] = count
        stack = [start]
        until stack.empty?
          backward[stack.pop].each do |source|
            next if component[source]

            component[source] = count
            stack << source
          end
        end
        count += 1
      end
      component
    end
  end
end
