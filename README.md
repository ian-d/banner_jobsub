# BannerJobsub

BannerJobsub is a Ruby gem that makes it easy to write Banner jobsub programs in Ruby instead of Pro*C. Increased readability, maintainability, and usefulness plus it gets you the power and flexibility of Ruby's standard library and available gems. By default, BannerJobsub will perform basic boilerplate operations for your job:
- Creates an oci8 database connection, including validating/applying Banner security.
- Creates output `.lis` file and swaps `STDOUT` to it, also provides `#log` file handle to write to logfile.
- Fetches submitted GJBPRUN parameter values into named hash.
- Provides default header / footer for formatr output.

## Installation
Using `gem` on your jobsub server:
```
gem install banner_jobsub
```

## Requirements
 - [Ruby](https://www.ruby-lang.org/en/documentation/installation/) >= 2.1.0
 - [ruby-oci8](https://rubygems.org/gems/ruby-oci8) >= 2.2.1
 - [formatr](https://rubygems.org/gems/formatr) >= 1.10.1

## Configuration
BannerJobsub expects standard/global configuration values to be stored in `$BANNER_HOME/admin/banner_jobsub.yaml`. Basic, minimum required values are your SEED1 and SEED3 values:
```yaml
seed_one: 111111111
seed_three: 22222222
```

**Banner 9 / bannerjsproxy** 
If you are using Banner Job Submission Proxy (bannerjsproxy) with either Banner 8 INB or Banner 9 Admin Pages, you can enable bannerjsproxy compatibility using the (optional) configuration setting. Defaults to disabled.
```yaml
seed_one: 111111111
seed_three: 22222222
banjsproxy: enabled
```

More options and configuration values are covered below.

## Installing a Job
Setting up a Ruby program to run via jobsub / INB GJAPCTL is basically the same a compiled Pro*C:

1. Create necessary job and security entries in Banner (GJBJOBS, GJBPDEF, etc) like a normal Pro*C job.
2. Place Ruby program _without an extension_ ("gyrruby" in this example) in `$BANNER_HOME/general/exe` (or symlink it there from the appropriate "mods" directory, up to you).
3. Set the executable bit on the program:`chmod +x $BANNER_HOME/general/exe/gyrruby`

## Examples
A few examples are provided in the `examples/` directory. Basic usage is covered in [examples/gyrruby](examples/gyrruby).

## Developing with BannerJobsub
BannerJobsub tries to make the development phase a little less painful by providing a a couple of convenience features when running a job from the command line.

**Credentials**: BannerJobsub will never prompt for username/password database credentials. Instead, it expects username and password to be provided in `~/.banner_jobsub`:
```yaml
username: scott
password: tiger
```

**Parameters**: To make repeated debugging/testing runs easier, BannerJobsub will look for `jobname.yaml` (ex: `gyrruby.yaml`, `syrblah.yaml`, etc) in the current directory and load matching parameter values from it.

So for this declaration in `gyrruby`:
```ruby
require 'banner_jobsub'
@env = BannerJobsub::Base.new(name: "GYRRUBY", params: [:start_date, :end_date])
```

BannerJobsub will look for `gyrruby.yaml` in the current directory to load parameter values:
```yaml
start_date: 01-JAN-2015
end_date: 31-DEC-2015
```

If not found, BannerJobsub will prompt for each parameter in turn. Multi-value parameters should be separated by a comma.

**Output Formatting**: BannerJobsub suggests using [formatr](https://rubygems.org/gems/formatr) for tabular/fixed output formatting, as it provides "visual" layouts (perlform, essentially). Much easier than using `table(...)` based formatting. `BannerJobsub::Base#print_header` and `BannerJobsub::Base#print_footer` provide simple page header/footer outputs. More information can found at the [formatr docs](http://www.rubydoc.info/gems/formatr/1.10.1/FormatR/Format), the [perlform docs](http://perldoc.perl.org/perlform.html), and in the provided simple [output example](examples/gyrruby).
