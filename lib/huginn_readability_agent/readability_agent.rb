module Agents
  class ReadabilityAgent < Agent
    include FormConfigurable

    no_bulk_receive!
    can_dry_run!
    cannot_be_scheduled!

    gem_dependency_check { defined?(Readability) }

    description <<-MD
      The Readability Agent extracts the primary readable content of a website.

      #{'## Include `ruby-readability` in your Gemfile to use this Agent!' if dependencies_missing?}

      `data` HTML to use in the extraction process, use [Liquid](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid) formatting to select data from incoming events.

      `tags` comma separated list of HTML tags to sanitize

      `remove_empty_nodes` remove `<p>` tags that have no text content; also removes `<p>` tags that contain only images

      `attributes` comma separated whitelist of allowed HTML tag attributes

      `blacklist` CSS selector of elements to explicitly remove

      `whitelist` CSS selector of elements to explicitly scope to

      `result_key` sets the key which contains the the extracted information.

      `merge` set to true to retain the received payload and update it with the extracted result

      `clean_output` Removes `\\t` charcters and duplicate new lines from the output when set to `true`.

      [Liquid](https://github.com/cantino/huginn/wiki/Formatting-Events-using-Liquid) formatting can be used in all options.
    MD

    event_description do
      event = Utils.pretty_print(interpolated['result_key'] => {'title' => 'Title', 'content' => 'Extracted content', 'author' => 'Author'})
      "Events will looks like this:\n\n    #{event}"
    end

    def default_options
      {
        'data' => '{{body}}',
        'tags' => 'div, p',
        'remove_empty_nodes' => 'false',
        'attributes' => '',
        'blacklist' => '',
        'whitelist' => '',
        'merge' => 'false',
        'clean_output' => 'true',
        'result_key' => 'data'
      }
    end

    form_configurable :data
    form_configurable :tags
    form_configurable :remove_empty_nodes, type: :boolean
    form_configurable :attributes
    form_configurable :blacklist
    form_configurable :whitelist
    form_configurable :merge, type: :boolean
    form_configurable :clean_output, type: :boolean
    form_configurable :result_key

    def validate_options
      errors.add(:base, "data needs to be present") if  options['data'].blank?
    end

    def working?
      received_event_without_error?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        mo = interpolated(event)

        options = {tags: split(mo['tags']), remove_empty_nodes: boolify(mo['remove_empty_nodes']) }
        options[:attributes] = split(mo['attributes']) if mo['attributes'].present?
        options[:whitelist] = mo['whitelist'] if mo['whitelist'].present?
        options[:blacklist] = mo['blacklist'] if mo['blacklist'].present?

        res = Readability::Document.new(mo['data'], options)

        content = if boolify(mo['clean_output'])
          res.content.gsub('&#13;', "\n").gsub("\\t", '').gsub("\\n", "\n").gsub(/([\n|\r\n|]\s*)+/, "\n")
        else
          res.content
        end

        payload = boolify(mo['merge']) ? event.payload : {}
        payload.merge!({ mo['result_key'] => { title: res.title, content: content, author: res.author} })

        create_event payload: payload
      end
    end

    private

    def split(string)
      string.split(",").map(&:strip)
    end
  end
end
