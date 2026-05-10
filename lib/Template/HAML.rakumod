
use Template::HAML::Actions;
use Template::HAML::Config;
use Template::HAML::Node;
use Template::HAML::Renderer;
use Template::HAML::Grammar;
use Template::HAML::X;

class HAML is export {
  has Template::HAML::Config $.config;

  submethod BUILD(Template::HAML::Config :$config) {
    $!config = $config // Template::HAML::Config.new;
  }

  multi method render(HAML:U: Str:D :$src, :%locals, Template::HAML::Config :$config) {
    my $cfg = $config // Template::HAML::Config.new;
    self!do-render($src, %locals, $cfg);
  }

  multi method render(HAML:D: Str:D :$src, :%locals, Template::HAML::Config :$config) {
    my $cfg = $config // $!config // Template::HAML::Config.new;
    self!do-render($src, %locals, $cfg);
  }

  method !do-render(Str:D $src, %locals, Template::HAML::Config $cfg) {
    my $tree = Node.new;
    $tree.add-child(Node.new);
    my $actions = Actions.new(:$tree, :config($cfg));

    my $normalized = $src.subst(:global, /\r\n/, "\n").subst(:global, /\r/, "\n");

    my $m = Grammar.parse($normalized, :$actions);
    unless $m {
      X::HAML::ParseFail.new(:line(1), :column(1), :snippet($normalized.lines.first // '')).throw;
    }

    Renderer.new(:%locals, :config($cfg)).render($actions.tree);
  }
}
