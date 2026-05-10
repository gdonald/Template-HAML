
use Template::HAML::Actions;
use Template::HAML::Node;
use Template::HAML::Renderer;
use Template::HAML::Grammar;
use Template::HAML::X;

class HAML is export {
  method render(Str:D :$src, :%locals) {
    my $tree = Node.new;
    $tree.add-child(Node.new);
    my $actions = Actions.new(:$tree);

    my $normalized = $src.subst(:global, /\r\n/, "\n").subst(:global, /\r/, "\n");

    my $m = Grammar.parse($normalized, :$actions);
    unless $m {
      X::HAML::ParseFail.new(:line(1), :column(1), :snippet($normalized.lines.first // '')).throw;
    }

    Renderer.new(:%locals).render($actions.tree);
  }
}
