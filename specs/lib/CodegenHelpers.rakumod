use MONKEY-SEE-NO-EVAL;
use BDD::Behave;
use Template::HAML;
use Template::HAML::Config;
use Template::HAML::Context;
use Template::HAML::DirectCodegen;
use Template::HAML::ViewContext;

unit module CodegenHelpers;

sub direct-render(
  Str $src, %locals = %(),
  Template::HAML::Config :$config,
  :$context,
) is export {
  my $cfg  = $config // Template::HAML::Config.new;
  my $tree = HAML.parse-source(:$src, :config($cfg));
  my $code = DirectCodegen.new(:config($cfg)).emit-direct($tree);
  my &fn   = EVAL $code;
  my $ctx  = Template::HAML::Context.new(
    :haml(HAML),
    :user-context($context // Template::HAML::ViewContext.new),
  );
  &fn(%locals, :_haml_ctx($ctx));
}

sub clone-locals(%h) {
  my %out;
  for %h.kv -> $k, $v {
    %out{$k} = $v ~~ Positional ?? $v.clone !! $v ~~ Associative ?? $v.clone !! $v;
  }
  %out;
}

sub round-trip-check(
  Str $src, %locals,
  Template::HAML::Config :$config,
  :$context,
) is export {
  my $expected = HAML.render(:$src, :locals(clone-locals(%locals)), :$config, :$context);
  my $actual   = direct-render($src, clone-locals(%locals), :$config, :$context);
  expect($actual).to.eq($expected);
}
