DeepCover.configure do
  output 'coverage/report-deep-cover'
  paths %w(./lib)
  #reporter :istanbul
end

autoload :Sass, 'sass'
class DeepCover::Reporter::HTML::Site
  def compile_stylesheet source, dest
    IO.write dest, (Sass::Engine.for_file source, style: :compressed).to_css
  end
end
