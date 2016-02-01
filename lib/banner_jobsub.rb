# rubocop:disable Metrics/LineLength
require 'formatr'
require 'oci8'
require 'yaml'
require 'banner_jobsub/version'

module BannerJobsub
  ##
  # Represents the current Banner environment the job is running in. At initilization,
  # configuration values are loaded from three sources (in increasing order of precedence):
  # - $BANNER_HOME/admin/banner_jobsub.yaml
  # - ~/.banner_jobsub
  # - +opts+ parameter of +new+
  #
  # Avaliable configuration values are:
  # * +username+ : The username used to connect to Banner database. (Defaults to $BANUID)
  # * +password+ : The password for +username+. (Defaults to $PSWD)
  # * +instance+ : The tnsnames name to connect to. (Defaults to $ORACLE_SID)
  # * +seed_one+ : The SEED1 value for the Banner instance.
  # * +seed_three+ : The SEED3 value for the Banner instance.
  # * +page_length+ : The default page length for FormatR output, configuration values are trumped by parameter #99 from jobsub. (Defaults to 55)
  # * +footer+ : The default footer for FormatR output. (Defaults to '\f')
  # * +header+ : The default header for FormatR output.
  #
  class Base
    attr_reader :name, :title, :params, :conn, :header, :footer, :log, :page_length

    def initialize(name:, params:, opts: {})
      @name = name
      @config = {
        username: ENV['BANUID'],
        password: ENV['PSWD'],
        instance: ENV['ORACLE_SID'],
        seed_one: nil,
        seed_three: nil,
        page_length: 55,
        footer: '\f',
        header: ''
      }

      configure_from_files
      configure_from_hash(opts)
      @config.each { |k, v| fail "Required configuration parameter \"#{k}\" is null." if v.nil? }

      set_db_connection
      set_role_security

      @title = @conn.select_one('SELECT GJBJOBS_TITLE FROM GJBJOBS WHERE GJBJOBS_NAME = :1', @name)[0]

      get_parameters(params)
      @page_length = @config[:page_length].to_i if @page_length.nil?

      set_header
      set_footer

      # Manage STDOUT/LOG
      @log = $stdout
      $stdout = File.new(ARGV[2], 'w') if ARGV[2]
    end

    def print_header(page_number = 1)
      temp_fmt = FormatR::Format.new(@header, '')
      temp_fmt.printFormatWithHash('PAGE_NUMBER' => page_number)
    end

    def print_control_page(page_number = '')
      control_format =  "Paramater Name                    Parameter Value\n"
      control_format += '------------------------          ---------------'
      line_format    =  "@<<<<<<<<<<<<<<<<<<<<<<<          @<<<<<<<<<<<<<<\n"
      line_format += 'PARAM_NAME,                       PARAM_VALUE'
      temp_fmt = FormatR::Format.new(@header + control_format, line_format)
      @params.each do |k, v|
        h = { 'PARAM_NAME' => k, 'PARAM_VALUE' => v, 'PAGE_NUMBER' => page_number }
        temp_fmt.printFormatWithHash(h)
      end
    end

    private def get_parameters(params)
      @params = {}
      params_def = []
      cur = @conn.exec('SELECT * FROM GJBPDEF WHERE GJBPDEF_JOB = :1 ORDER BY GJBPDEF_NUMBER', @name)
      while (r = cur.fetch_hash)
        p_def = r.each_with_object({}) { |(k, v), m| m[k.downcase.to_sym] = v }
        p = params[p_def[:gjbpdef_number].to_i - 1]
        @params[p] = p_def[:gjbpdef_single_ind] == 'S' ? nil : []
        params_def << p_def
      end
      cur.close

      if ENV['ONE_UP']
        get_parameter_values_from_db(params, params_def)
      elsif File.exist?("#{@name.downcase}.yaml")
        get_parameter_values_from_file
      else
        get_parameter_values_from_prompt(params, params_def)
      end
    end

    private def get_parameter_values_from_file
      YAML.load(IO.read("#{@name.downcase}.yaml")).each { |k, v| @params[k.to_sym] = v }
    end

    private def get_parameter_values_from_db(params, params_def)
      cur = @conn.exec('SELECT * FROM GJBPRUN WHERE GJBPRUN_JOB = :1 AND GJBPRUN_ONE_UP_NO = :2 ORDER BY GJBPRUN_NUMBER', @name, ENV['ONE_UP'])
      while (r = cur.fetch_hash)
        p_num = r['GJBPRUN_NUMBER'].to_i
        if p_num == 99
          @page_length = r['GJBPRUN_VALUE'].to_i
          next
        end
        if p_num > params.count then fail "FATAL: GJBPRUN parameter number #{p_num} greater than passed parameter list." end
        p = params[p_num - 1]
        if params_def[p_num - 1][:gjbpdef_single_ind] == 'S'
          @params[p] = r['GJBPRUN_VALUE']
        else
          @params[p] << r['GJBPRUN_VALUE']
        end
      end
      if cur.row_count == 0 then fail "FATAL: Unable to validate one up ##{ENV['ONE_UP']} with job #{@name}." end
      cur.close

      @conn.exec('DELETE FROM GJBPRUN WHERE GJBPRUN_JOB = :1 AND GJBPRUN_ONE_UP_NO = :2', @name, ENV['ONE_UP'])
    end

    private def get_parameter_values_from_prompt(params, params_def)
      params.each_index do |i|
        p = params[i]
        @params[p] = (print "Value for #{p}: "; gets.chomp)
        @params[p] = @params[p].split(',') if params_def[i][:gjbpdef_single_ind] == 'M'
      end
    end

    private def configure_from_hash(opts)
      opts.each { |k, v| @config[k.to_sym] = v if @config.keys.include?(k.to_sym) }
    end

    private def configure_from_files
      files = ["#{ENV['BANNER_HOME']}/admin/banner_jobsub.yaml", "#{Dir.home}/.banner_jobsub"]
      files.each do |f|
        begin
          config = YAML.load(IO.read(f))
          config.each { |k, v| @config[k.to_sym] = v if @config.keys.include?(k.to_sym) }
        rescue Errno::ENOENT # Ignore missing file exceptions.
        rescue Psych::SyntaxError => e
          raise "Error parsing YAML in #{f}: #{e}"
        end
      end
    end

    private def set_db_connection
      @conn = OCI8.new(@config[:username], @config[:password], @config[:instance])
    end

    private def set_role_security
      password = ''

      cursor = @conn.parse('begin bansecr.g$_security_pkg.g$_verify_password1_prd(:p_object,:p_version,:p_password, :p_role); end;')
      cursor.exec @name, [nil, String], [nil, String], [nil, String]

      return if cursor[3] == 'INSECURED'

      @conn.exec('begin :p_result := G$_SECURITY.G$_DECRYPT_FNC( :p_password, :p_seed ); end;', ['', String, 255], [cursor[3], String, 255], [@config[:seed_three], Fixnum]) { |*outvars| password = outvars[0] }

      cursor = @conn.parse('begin bansecr.g$_security_pkg.g$_verify_password1_prd(:p_object,:p_version,:p_password, :p_role); end;')
      cursor.exec @name, [nil, String], [password, String], [nil, String]

      @conn.exec('begin :p_result := G$_SECURITY.G$_DECRYPT_FNC( :p_password, :p_seed ); end;', ['', String, 255], [cursor[3], String, 255], [@config[:seed_one], Fixnum]) { |*outvars| password = outvars[0] }

      @conn.exec("begin DBMS_SESSION.SET_ROLE('#{cursor[4]} IDENTIFIED BY \"#{password}\"'); end;")
    end

    private def set_footer
      @footer = @config[:footer]
    end

    private def set_header
      if !@config[:header].empty?
        @header = @config[:header]
      else
        inst = get_institution_name
        @header = <<EOH
#{Time.now.strftime('%d-%b-%Y %I:%M %p').upcase} #{inst.center(110)} PAGE: @<<<
PAGE_NUMBER
#{@name} #{@title.center(132)}
EOH
      end
    end

    private def get_institution_name
      @conn.select_one('SELECT GUBINST_NAME FROM GUBINST WHERE GUBINST_KEY = \'INST\'')[0]
    end
  end
end
