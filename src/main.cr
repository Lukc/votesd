require "kemal"
require "html_builder"
require "markdown"

class Vote
	property title : String
	property description : String?
	getter ballots = Array(Ballot).new

	def initialize(@title, @description = nil)
	end

	def set_voters(voters : Array(String))
		voters.each { |x| ballots << Ballot.new x }
	end

	def set_ballots(@ballots)
	end

	enum Status
		ACCEPTED
		REJECTED
	end

	def status
		status = Status::REJECTED

		@ballots.each do |ballot|
			next unless ballot.decisive

			if ballot.type == Ballot::Type::OPPOSED_TO
				return Status::REJECTED
			elsif ballot.type == Ballot::Type::IN_FAVOR
				status = Status::ACCEPTED
			end
		end

		status
	end

		def symbols
			case status
			when Status::ACCEPTED
				{"☑", "success"}
			when Status::REJECTED
				{"☒", "danger"}
			else
				{"☐", "primary"}
			end
		end

	class Ballot
		enum Type
			IN_FAVOR
			OPPOSED_TO
			WITHOUT_OPINION
			UNSET
			INVALID # Usually, technical errors.

			def self.from_s(s)
				case s.downcase
				when "in favor"
					IN_FAVOR
				when "opposed to"
					OPPOSED_TO
				when "without opinion"
					WITHOUT_OPINION
				when "unset"
					UNSET
				else
					INVALID
				end
			end
		end

		property user : String
		property type : Type
		property comment : String?
		property decisive = true

		def initialize(@user, decisive = true)
			@decisive = decisive unless decisive.nil?

			@type = Type::UNSET
			@comment = nil
		end

		def initialize(@type, @user, @comment = nil, decisive = nil)
			@decisive = decisive unless decisive.nil?

			case @type
			when Type::IN_FAVOR, Type::OPPOSED_TO, Type::WITHOUT_OPINION
			when Type::UNSET, Type::INVALID
				@comment = nil
			else
				@type = Type::UNSET
				@comment = nil
			end
		end

		def symbols
			case @type
			when Type::IN_FAVOR
				{"⊕", "success"}
			when Type::OPPOSED_TO
				{"⊗", "danger"}
			when Type::WITHOUT_OPINION
				{"⊜", "black"}
			when Type::UNSET
				{"◌", "light"}
			else
				{"◍", "primary"}
			end
		end
	end
end

class VotesList
	def self.each
		Dir.each_child "data" do |entry|
			file_path = "data/" + entry

			content = JSON.parse File.read file_path

			title = content["title"].as_s
			description = content["description"]?.try &.as_s

			yield Vote.new(Markdown.to_html(title), description.try { |s| Markdown.to_html s}).tap do |vote|
				ballots = Array(Vote::Ballot).new

				content["ballots"]?.try &.as_a?.try &.each do |ballot|
					ballots << Vote::Ballot.new(
						Vote::Ballot::Type.from_s(ballot["type"].as_s),
						ballot["user"].as_s,
						ballot["comment"]?.try &.as_s?.try { |x| Markdown.to_html x},
						ballot["decisive"]?.try &.as_bool?
					)
				end

				vote.set_ballots ballots
			end
		end
	end
end

class Voter
	getter name : String
	getter decisive : Bool

	def initialize(@name, @decisive = false)
	end
end

class Voters	
	def self.each
		yield Voter.new "Lukc", decisive: true
		yield Voter.new "Good Lukc", decisive: true
		yield Voter.new "Bad Lukc", decisive: true
		yield Voter.new "Uncertain Lukc", decisive: true
	end
end


get "/" do
	HTML.build {
		doctype

		html {
			head {
				html "<meta charset=\"utf-8\"/>"
				link href: "https://cdnjs.cloudflare.com/ajax/libs/bulma/0.7.1/css/bulma.min.css", rel: "stylesheet"
				link href: "https://raw.githubusercontent.com/Wikiki/bulma-tooltip/master/dist/css/bulma-tooltip.min.css", rel: "stylesheet"
				link href: "https://tartines.org/style.css", rel: "stylesheet"
				html %(
				<style>
					hr {
						background: transparent;
					}
				</style>
				)
			}
			div class: "container" {
				div id: "header" {
					h1 {
						text "votesd"
					}
					div id: "subtitle" {
						text "Version 0.0.1"
					}
				}

				div class: "section" {
					h3 class: "title is-3" {
						text "Current Voting Rights"
					}

					ul {
						Voters.each do |voter|
							# Granted access to the voting system but does vote is still only consultative.
							next unless voter.decisive

							li {
								text voter.name
							}
						end
					}
				}

				hr
				VotesList.each do |vote|
					div class: "section" {
						div class: "fixme" {
							div class: "title is-2" {
								html vote.title
							}

							div class: "content" {
								text "Status: "

								symbol, color = vote.symbols
								span class: "tag is-#{color} is-large" {
									text symbol
									text " "
									text vote.status.to_s
								}
							}

							vote.description.try { |description|
								div class: "content" {
									html description
								}
							}

							div class: "message" {
								div class: "message-header" {
									text "Core Voters"
								}

								div class: "message-body" {
									div class: "tags" {
										vote.ballots.select(&.decisive).each do |ballot|
											symbol, color = ballot.symbols

											span class: "tag is-#{color} is-large tooltip", "data-tooltip": (ballot.user) {
												text symbol
											}
										end
									}
								}
							}

							# FIXME: Basically duplicated the code above.
							div class: "message" {
								div class: "message-header" {
									text "Other People"
								}

								div class: "message-body" {
									div class: "tags" {
										vote.ballots.select(&.decisive.!=(true)).each do |ballot|
											symbol, color = ballot.symbols

											span class: "tag is-#{color} is-large" {
												text symbol
											}
										end
									}
								}
							}

							if vote.ballots.select(&.comment).size > 0
								div class: "title is-4" {
									text "Comments"
								}
							end

							vote.ballots.each do |ballot|
								comment = ballot.comment

								next unless comment

								symbol, color = ballot.symbols

								div class: "media" {
									div class: "media-left" {
										span class: "tag is-#{color} is-large" {
											text symbol
										}
									}

									div class: "media-content" {
										span class: "title is-6 heading" {
											text ballot.user
										}

										html comment
									}
								}
							end
						}
					}
					hr
				end
			}
		}
	}
end

Kemal.run

