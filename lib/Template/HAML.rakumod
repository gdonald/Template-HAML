
use Template::HAML::Actions;
use Template::HAML::Node;
use Template::HAML::Renderer;
use Template::HAML::Grammar;

class HAML is export {
  method render(Str:D :$src) {
    my $tree = Node.new;
    $tree.add-child(Node.new);
    my $actions = Actions.new(:$tree);

    my $normalized = $src.subst(:global, /\r\n/, "\n").subst(:global, /\r/, "\n");

    Grammar.parse($normalized, :$actions);
    Renderer.render($actions.tree);
  }
}
