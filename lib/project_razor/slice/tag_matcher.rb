# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "json"



module ProjectRazor
  module Slice
    # ProjectRazor Tag Slice
    # Tag
    # @author Nicholas Weaver
    class Tagmatcher < ProjectRazor::Slice::Base

      # init
      # @param [Array] args
      def initialize(args)
        super(args)
        @hidden = false
        # Define your commands and help text
        @slice_commands = {:default => "must_have_get",
                           :get => "get_tag_matcher",
                           :add => "add_tag_matcher",
                           :remove => "remove_tag_matcher",
        }
        @slice_commands_help = {:get => "tagmatcher".red + " [add|remove|get] (tag rule uuid)".blue,
                                :add => "tagmatcher".red + " add (tag rule uuid) (key) (value) [equal|like]".blue + " {inverse}".yellow,
                                :remove => "tagmatcher".red + " remove (tag rule uuid) (tag matcher uuid)".blue}
        @slice_name = "Tagmatcher"
      end

      def must_have_get
        slice_error("InvalidCommand")
      end

      def get_tag_matcher
        @command = :get
        uuid = validate_tag_rule
        unless uuid
          return
        end

        print_object_array [@tag_rule], "Tag Rule" unless @web_command
        print_object_array @tag_rule.tag_matchers, "Tag Matchers"
      end

      def add_tag_matcher
        @command = :add
        uuid = validate_tag_rule
        unless uuid
          return
        end

        if @web_command
          add_tag_matcher_web(uuid)
        else
          key = @command_array.shift
          value = @command_array.shift
          compare = @command_array.shift
          inverse = @command_array.shift

          unless validate_arg(key)
            slice_error("MissingKey")
            return
          end
          unless validate_arg(value)
            slice_error("MissingValue")
            return
          end
          unless validate_arg(compare)
            slice_error("MissingCompare")
            return
          end
          unless inverse == nil
            unless inverse == "inverse"
              slice_error("InvalidInverseStatement")
              return
            end
          end

          unless compare == "equal" || compare == "like"
            slice_error("InvalidCompare")
            return
          end

          inverse = "true" if inverse
          inverse = "false" unless inverse

          if @tag_rule.add_tag_matcher(key, value, compare, inverse)
            if @tag_rule.update_self
              @command_array.unshift(@tag_rule.uuid)
              get_tag_matcher
            else
              slice_error("CouldNotUpdateTagRule")
              return
            end
          else
            slice_error("CouldNotAddMatcher")
            return
          end
        end
      end

      def add_tag_matcher_web(uuid)
        json_string = @command_array.shift
        if json_string != "{}" && json_string != nil
          begin
            post_hash = JSON.parse(json_string)
            if post_hash["@key"] != nil && post_hash["@value"] != nil && post_hash["@compare"] != nil && post_hash["@inverse"] != nil
              unless post_hash["@compare"] == "equal" || post_hash["@compare"] == "like"
                slice_error("InvalidCompare")
                return
              end

              unless post_hash["@inverse"] == "true" || post_hash["@inverse"] == "false"
                slice_error("InvalidInverse")
                return
              end

              if @tag_rule.add_tag_matcher(post_hash["@key"], post_hash["@value"], post_hash["@compare"], post_hash["@inverse"])
                if @tag_rule.update_self
                  @command_array.unshift(@tag_rule.uuid)
                  print_object_array [@tag_rule]
                else
                  slice_error("CouldNotUpdateTagRule")
                  return
                end
              else
                slice_error("CouldNotAddMatcher")
                return
              end
            else
              slice_error("MissingProperties")
            end
          rescue => e
            slice_error(e.message)
          end

        else
          slice_error("MissingAttributes")
        end
      end

      def remove_tag_matcher
        @command = :get
        uuid = validate_tag_rule
        unless uuid
          return
        end

        tag_matcher_uuid = @command_array.shift

        unless validate_arg(tag_matcher_uuid)
          slice_error("MustProvideTagMatcherUUID")
          @command_array.unshift(uuid)
          return get_tag_matcher
        end

        tag_matcher = nil
        @tag_rule.tag_matchers.each do
        |tm|
          tag_matcher = tm if tm.uuid == tag_matcher_uuid
        end

        unless tag_matcher
          slice_error("InvalidTagMatcherUUID")
          @command_array.unshift(uuid)
          return get_tag_matcher
        end

        @tag_rule.tag_matchers.delete(tag_matcher)
        if @tag_rule.update_self
          slice_success("TagMatcherRemoved") unless @web_command
          print_object_array [@tag_rule]
        else
          slice_error("CouldNotUpdateTagRule")
          return
        end
      end

      def validate_tag_rule
        uuid = @command_array.shift

        unless validate_arg(uuid)
          slice_error("MustProvideTagRuleUUID")
          print_object_array get_object("tag_rules", :tag), "Valid Tag Rules" unless @web_command
          return false
        end

        setup_data
        @tag_rule = @data.fetch_object_by_uuid(:tag, uuid)
        unless @tag_rule
          slice_error("CannotFindTagRule")
          print_object_array get_object("tag_rules", :tag), "Valid Tag Rules" unless @web_command
          return false
        end
        uuid
      end




    end
  end
end