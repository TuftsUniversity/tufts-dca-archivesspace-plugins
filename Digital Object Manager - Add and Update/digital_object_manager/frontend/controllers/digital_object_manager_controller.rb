###########################################################################################################################
###########################################################################################################################
###########################################################################################################################
###########################################################################################################################
########
########			File: 			digital_object_manager_controller.rb
########
########			Author:  		Kevin Clair
########
########			Edited by:		Henry Steele, 2017
########
########			Changes:
########		      - allow DOM to create a new digital object if one doesn't exist
########			  - OR, allow it to edit existing digital objects
########			
########			Note:
########			  - In order to configure this for your institution, you need to change the prefix you want to add 
########			    for digital objects.  At Tufts university, a digital object's identifier is like the archival 
########				object identifier, except it has the prefix "tufts:"   
########				
########				If you use a prefix like above with only letters and numbers, you only have to change 
########				the regex in the code below at "Regex Location 3"   If you use a different format, 
########				you'll have to change the code at regex locations 1, 2, and 3.  
########				These locations are noted in the code with a comment block
########			
########			Input:
########			  - The script expects a csv input file, like the original DOM.
########				But the input CSV must have 9 fields in each line, as listed below
########				They don't need a header row, but they need to be in this order
########					
########				  1) Title 						(string)
########				  2) PID   						(string)
########				  3) Handle 					(string with URL based on Tufts pattern )
########				  4) Location					(string)   
########					+ (In DCA's records, this is in User Defined Field "Text 1" in the digital object )
########				  5) Digital object publish		(Boolean)
########					
########				  6) Restrictions				(Boolean)
########				  7) File version publish		(Boolean)
########				  8) Checksum					(hexadecimal checksum hash)
########				  9) checksum method			(This must match whatever you have in your instance of ASpace)
########			  
########			  Method:
########			    - The script determines for each row if this is going to be an add or update operation by
########				  by how many fields have non-empty values.  
########				- If all the 9 fields above have values, then it assumes the user wants to create a digital object 
########				  and creates a new digital object under the archival object of the PID.
########				- If there are fewer than 9 fields with non-empty values, then it assumes the user wants to update
########			      a digital object and performs an update of all the attached digital objects with the supplied fields.
########				- Note that even if a field is blank, indicating an update, there must be
########				  exactly 9 comma-delimited fields in each row
########
########			  Output:
########			    - the updated or created digital object (in ArchivesSpace)
########				- the log file, with additional information about how many fields were updated
########		
########				
###########################################################################################################################
###########################################################################################################################
###########################################################################################################################
###########################################################################################################################
class DigitalObjectManagerController < ApplicationController

	require 'csv'
	require 'zip'
	require 'net/http'

	set_access_control "view_repository" => [:index, :download],
                     "update_digital_object_record" => [:update]

	def index
	end

	def download
		datafile = params[:datafile]
		case datafile.content_type
		when 'text/plain', 'text/csv', 'application/vnd.ms-excel'
			output = write_zip(datafile)
			output.rewind
			send_data output.read, filename: "mods_download_#{Time.now.strftime("%Y%m%d_%H%M%S")}.zip"
		else
			flash[:error] = I18n.t("plugins.digital_object_manager.messages.invalid_mime_type", :filename => "#{datafile.original_filename}")
			redirect_to :controller => :digital_object_manager, :action => :index
		end
	end

	def update
		datafile = params[:datafile]
		case datafile.content_type
		when 'text/plain', 'text/csv', 'application/vnd.ms-excel'
			file = update_records(datafile)
			file.rewind
			send_data file.read, filename: "activity_log.txt"
			file.close
			File.delete('activity_log.txt') if File.exist?('activity_log.txt')
		else
			flash[:error] = I18n.t("plugins.digital_object_manager.messages.invalid_mime_type", :filename => "#{datafile.original_filename}")
			redirect_to :controller => :digital_object_manager, :action => :index
		end
	end

	private
	##################################################
	#####  This method was updated by Tufts University
	def write_zip(datafile)
		output = Zip::OutputStream.write_buffer do |zos|
			log = Array.new
			datafile.read.each_line do |line|
				CSV.parse(line) do |row|
					parsedID = row[1]
					####################################################################################################
					####################################################################################################
					#########################			Regex Location 1					  ##########################
					####################################################################################################
					####################################################################################################
					####	the regex in the following line is configured to match the format used by 
					####	Tufts University Digital Collection & Archives.  You may need to adjust this according
					####	to the needs of your institution.
					
					parsedID = parsedID.gsub(/(\w\:)?(.+)/, '\2')
					search_data = Search.all(session[:repo_id], { 'q' =>  "\"#{parsedID}\""  })
					if search_data.results?
						search_data['results'].each do |result|
							obj = JSON.parse(result['json'])
							if obj['component_id'] = parsedID
								mods = download_mods(obj)
								unless mods.nil?
									zos.put_next_entry "#{parsedID.gsub(/\./, '_')}.xml"
									zos.print mods
									log.push("#{parsedID.gsub(/\./, '_')}.xml downloaded")
								end
								log.push("#{parsedID} found but no MODS record downloaded") if mods.nil?
							end
						end
					else
						log.push("#{parsedID} not found in ArchivesSpace")
					end
				end
			end
			zos.put_next_entry "action_log.txt"
			log.each do |entry|
				zos.puts entry
			end
		end
		return output
	end
	##################################################
	#####  This method was updated by Tufts University
	def update_records(datafile)
		file = File.new('activity_log.txt', 'a+')

	
		rowNumber = 1
		
			datafile.read.each_line do |line|
			
					CSV.parse(line) do |row|

						count = 0
						if row.length == 0
							log = "No data in input row #{rowNumber}"

						else
							if row.length <= 9 && row.length > 0
								if row[1].nil?
									log = "No PID to retrieve archival object #{rowNumber}"

								else

									if row[0] == "title" && row[1] == "pid"
										log << "Header row"
									else


										parsedID3 = row[1]
										count = count + 1
										####################################################################################################
										####################################################################################################
										#########################			Regex Location 2					  ##########################
										####################################################################################################
										####################################################################################################
										####	the regex in the following line is configured to match the format used by 
										####	Tufts University Digital Collection & Archives.  You may need to adjust this according
										####	to the needs of your institution.
										parsedID = parsedID3.gsub(/(\w+\:)?(.+)/, '\2')
										log = "#{parsedID}: "

										if search_data = Search.all(session[:repo_id], {
										"q" => "\"#{parsedID}\"" , "filter_term[]" => { "primary_type" => "archival_object" }.to_json
										})

											if search_data.results?
												search_data['results'].each do |result|
													begin obj = JSON.parse(result['json'])
														if obj['component_id'] = parsedID

															##############	check if each field exists.  If any don't, it's an update request.  If all do, it's a create request
															##############

															begin item = JSONModel::HTTP.get_json(obj['uri'])

															
																####################################################################################################
																####################################################################################################
																#########################			Regex Location 3					  ##########################
																####################################################################################################
																####################################################################################################
																####	the regex in the following line is configured to match the format used by 
																####	Tufts University Digital Collection & Archives.  You **will** need to adjust this according
																####	to the needs of your institution.
																####	
																####	Note that if you use the prefix format below, you should change the phrase to match
																####	your institution
																parsedID2 = parsedID.gsub(/(.+)/, '<your_institution>:\1')

															
																# the following statements check if there is a value in each of the 9 fields, 
																# and in several cases checks for spefic values like True/False
																if row[0].nil?
																	title = ""
																else
																	count = count + 1
																	title = row[0].strip
																end

															

																if row[2].nil?
													
																	handle = ""
																else
											
																	count = count + 1
																	handle = row[2]
																end

														

																if row[3].nil?
																	location = ""
																else
																	count = count + 1
																	location = row[3]
																end

												

																if row[4].nil?
																	do_publish = ""
																else
																	count = count + 1
																	if row[4] == "TRUE" || row[4] == "true" || row[4] == "True"
																		do_publish = true
																	else
																		do_publish = false
																	end
																end

											

																if row[5].nil?
																	res = ""
																else
																	count = count + 1
																	if row[5] == "Open for research."
																		res = false
																	else
																		res = true
																	end
																end

													

																if row[6].nil?
																	fv_publish = ""
																else
																	count = count + 1
																	if row[6] == "TRUE" || row[6] == "true" || row[6] == "True"
																		fv_publish = true
																	else
																		fv_publish = false
																	end
																end

										

																if row[7].nil?
																	checksum = ""
																else
																	count = count + 1
																	checksum = row[7]
																end

										

																if row[8].nil?
																	checksum_method = ""
																else
																	if row[8] != "md5" && row[8] != "sha-1" && row[8] != "sha-256" && row[8] != "sha-384" && row[8] != "sha-512"  && row[8] != "Advanced Checksum Verifier" && row[8] != "md5 UNIX" && row[8] != "Bagger 2.1.2" && row[8] != "NA" && row[8] != "python hashlib" && row[8] != "Advanced Checksum" && row[8] != "Bagger 2.6.2" && row[8] != "UNIX md5" && row[8] != "Bagger" && row[8] != "Bagger 2.1.3" && row[8] != "Bagger 2.1.3." && row[8] != "Bagger2.1.3" && row[8] != "Bagger2.1.3." && row[8] != "MD5 and SHA Checksum Utility" && row[8] != "Bagger-2.7.7" && row[8] != "Bagger 2.7.7"
																		checksum_method = "Invalid checksum method"
																	else
																		count = count + 1
																		checksum_method = row[8]
																	end
																end

																# this is for creating a new digital object
																# only create a new digital object if there are no existing digital object instances
																# under the archival object
																if count > 0 && count <= 9

																	if count == 9
																		if item['instances'].empty?
																			begin item, log = add_digital_object(item, handle, log, parsedID2, title, do_publish, res, fv_publish, location, checksum, checksum_method, rowNumber)

																			rescue
																				log << "Couldn't add digital object for row #{rowNumber}"
																			end
																		else
																			if item['instances'].map{ |i| i['instance_type'] }.include?("digital_object")
																				log << "There is already a digital object for row #{rowNumber}"


																			else
																				begin
																					item, log = add_digital_object(item, handle, log, parsedID2, title, do_publish, res, fv_publish, location, checksum, checksum_method, rowNumber)

																				rescue
																					log << "Couldn't add digital object for row #{rowNumber}"
																				end
																			end


																		end


																	# this is for updating an existing digital object
																	elsif count > 0 && count < 9
													
																		if item['instances'].map{ |i| i['instance_type'] }.include?("digital_object")
																			item['instances'].each do |instance|

																				begin
																					log = update_digital_object(instance, handle, log, parsedID2, title, do_publish, res, fv_publish, location, checksum, checksum_method, rowNumber, count)

																				rescue
																					log << "Couldn't edit digital object for #{parsedID}"
																				end
																			end

																		else
																			log << "No digital object to update for input row  #{rowNumber}"
																		end
																	else
																		log << "Wrong number of fields in input row  #{rowNumber}"
																	end

																	begin
																		JSONModel::HTTP.post_json(URI("#{JSONModel::HTTP.backend_url}#{obj['uri']}"), item.to_json)
																	rescue
																		log << "Can't post archival object for input in row #{rowNumber}"
																	end
																else
																	log << "Wrong number of fields in input row  #{rowNumber}"
																end

															rescue
																log << "Can't return json item from AO URI for row #{rowNumber}"

															end

														else
															log << "can't assign PID from input for row #{rowNumber}"
														end
													rescue
														log << "Can't get the JSON representation of the archival object for row #{rowNumber} - AO: #{parsedID}"
													end
												end
											else
												log << "No matching archival object for input row #{rowNumber}"

											end
										else
											log << "Can't execute search for input row  #{rowNumber}"
										end

									end # end else not the header row
								end

							else
								log << "Wrong number of fields in input row  #{rowNumber}"
							end
						end

						file.puts(log)
					end

	
				rowNumber = rowNumber + 1
			end

		return file
	end

	def download_mods(obj)
		id = obj['uri'].gsub(/\/repositories\/#{session[:repo_id]}\/archival_objects\//, '')
		url = URI("#{JSONModel::HTTP.backend_url}/repositories/#{session[:repo_id]}/archival_objects/mods/#{id}.xml")
		req = Net::HTTP::Get.new(url.request_uri)
		req['X-ArchivesSpace-Session'] = Thread.current[:backend_session]
		resp = Net::HTTP.start(url.host, url.port) { |http| http.request(req) }
		mods = resp.body if resp.code == "200"

		return mods
	end

	def add_item_link(item, handle, log)
		item['external_documents'].push(JSONModel(:external_document).new({
			:title => I18n.t("plugins.digital_object_manager.defaults.link_title"),
			:location => "#{I18n.t("plugins.digital_object_manager.defaults.prefix")}#{handle}",
			:publish => true
		}))
		log << "Added Fedora handle #{handle} to #{item['uri']}. "
		return item, log
	end

	def update_item_link(item, handle, log)
		item['external_documents'].each do |doc|
			if doc['title'] == I18n.t("plugins.digital_object_manager.defaults.link_title")
				unless doc['location'].end_with?(handle)
					doc['location'].gsub!(/http\:\/\/hdl\.handle\.net\/\d+\/\d+$/, handle)
					log << "Updated #{item['uri']} with Fedora handle #{handle}. "
				end
			end
		end
		return item, log
	end
	##################################################
	#####  This method was updated by Tufts University
	def add_digital_object(item, handle, log, identifier, title, do_publish, restrictions, file_version_publish, location, checksum, checksum_method, rN)

		if checksum_method == "" || checksum_method == "Invalid checksum method"
			object = JSONModel(:digital_object).new({
				'title' => title,
				'digital_object_id' => identifier,
				'user_defined' => {'text_1' => location},
				'publish' => do_publish,
				'restrictions' => restrictions,
				'file_versions' => [{'checksum' => checksum, 'file_uri' => handle, 'publish' => file_version_publish}],
			}).to_json
		else
			object = JSONModel(:digital_object).new({
				'title' => title,
				'digital_object_id' => identifier,
				'user_defined' => {'text_1' => location},
				'publish' => do_publish,
				'restrictions' => restrictions,
				'file_versions' => [{'checksum' => checksum, 'checksum_method' => checksum_method, 'file_uri' => handle, 'publish' => file_version_publish}],
			}).to_json
		end

		begin
			resp = JSONModel::HTTP.post_json(URI("#{JSONModel::HTTP.backend_url}/repositories/#{session[:repo_id]}/digital_objects"), object)
		rescue
			log << "Can't post digital object for input in row #{rN}"
		end

		if resp.code == "200"
			uri = ASUtils.json_parse(resp.body)['uri']
			item['instances'].push(JSONModel(:instance).new({
				:instance_type => "digital_object",
				:digital_object => {
					:ref => uri
				}
			}))

			if checksum_method == "Invalid checksum method"
				message = ".  Invalid checksum method"

			else
				message = ""
			end

			log << "Created #{uri} with Fedora handle #{handle}. Linked #{uri} to #{item['uri']}. #{message}"

		else
			log << "Unable to post created digital object to repository for input row number  #{rN}"
		end

		return item, log
	end
	##################################################
	#####  This method was updated by Tufts University
	def update_digital_object(instance, handle, log, parsedID_from_file, title, do_publish, restrictions, file_version_publish, location, checksum, checksum_method, rN, c)

		begin
			object = JSONModel::HTTP.get_json(instance['digital_object']['ref'])

			identifier = object["digital_object_id"]

		rescue
			log << "Problems receiving digital object for #{parsedID_from_file}"
		end


		updatedCount = c - 1



		if title != ""
			object['title'] = title
		end

		if do_publish != ""
			object['publish'] = do_publish
		end

		if restrictions != ""
			object['restrictions'] = restrictions
		end

		if location != ""
			if object['user_defined'].nil?
				object['user_defined'] = { 'text_1' => location }
			else
				object['user_defined']['text_1'] = location
			end

		end
		
		arrayLength = object['file_versions'].length

		if arrayLength == 0
			object['file_versions'].push(JSONModel(:file_version).new())
			
		end
		if file_version_publish != ""
			object['file_versions'][0]['publish'] = file_version_publish
		end

		if handle != ""
			object['file_versions'][0]['file_uri'] = handle
		end

		if checksum != ""
			object['file_versions'][0]['checksum'] = checksum
		end

		if checksum_method != ""
			if checksum_method != "Invalid checksum method"
				object['file_versions'][0]['checksum_method'] = checksum_method
			else
				message = ".  Invalid checksum method"
			end

		end
		



		begin
			resp = JSONModel::HTTP.post_json(URI("#{JSONModel::HTTP.backend_url}#{instance['digital_object']['ref']}"), object.to_json)

		rescue
			log << "Problem with posting #{identifier}"
		end

		if resp.code == "200"

			log << "Updated #{updatedCount} fields in #{identifier} to #{object['uri']} #{message}\n"
		else
			log << "Unable to post created digital object to repository for input row number  #{rN} \n"
		end
	

		begin
			object = JSONModel::HTTP.get_json(instance['digital_object']['ref'])

			identifier = object["digital_object_id"]

		rescue
			log << "End - Problems receiving digital object for #{parsedID_from_file}"
		end
		

		
		return log
	end



end
