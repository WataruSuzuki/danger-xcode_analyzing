module Danger
    class DangerXcodeAnalyzing < Plugin
        require 'Fileutils'
        require 'rexml/document'

        attr_accessor :diff_files
        def diff_files
            return diff_files = (git.modified_files - git.deleted_files) + git.added_files
        end

        attr_accessor :xcodebuild_project
        attr_accessor :xcodebuild_scheme
        attr_accessor :xcodebuild_configuration

        attr_accessor :analyzedResultsDir
        def analyzedResultsDir
            return 'clang/' + @analyzedResultsDir
        end

        def report
            if xcodebuild_project.empty? && xcodebuild_scheme.empty?
                warn("(- -;;) dangerプラグインのエラー", sticky: false)
                return
            end

            system "xcodebuild analyze -project #{xcodebuild_project} -scheme #{xcodebuild_scheme} -configuration #{xcodebuild_configuration} CLANG_ANALYZER_OUTPUT=plist CLANG_ANALYZER_OUTPUT_DIR=\"$(pwd)/clang\""

            unless FileTest.exists? analyzedResultsDir
                fail("(・A・)!! #{analyzedResultsDir}が見当たりません、ビルドに失敗しているか無効なディレクトリ指定です", sticky: false)
                return
            end

            Dir.foreach(analyzedResultsDir) do |file|
                puts file
                if file.end_with?(".plist")
                    targetFileName = nil
                    doc = REXML::Document.new(File.new(analyzedResultsDir + "/" + file))
                    doc.elements.each("plist/dict/array") do |element|
                        element.elements.each("string") do |filename|
                            diff_files.each do |target|
                                if filename.text.include? target
                                    targetFileName = target
                                end
                            end
                        end
                        unless targetFileName == nil
                            element.elements.each("dict/array/dict/dict") do |child|
                                if child.elements['key'].text == 'line'
                                    element.elements.each("dict/array/dict") do |messages|
                                        messages.elements.each_with_index() do |key, index|
                                            if key.text == "message"
                                                offset = (index + 2) # <- 1始まり、かつ次の要素
                                                message = messages.elements[offset].text
                                                unless message.empty?
                                                    warn(message, file: targetFileName, line: child.elements['integer'].text.to_i)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end
