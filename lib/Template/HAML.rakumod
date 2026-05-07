
use Template::HAML::Actions;
use Template::HAML::Node;
use Template::HAML::Renderer;
use Template::HAML::Grammar;

class HAML is export {
  method render(Str:D :$src) {
    my $tree = Node.new;
    $tree.add-child(Node.new);
    my $actions = Actions.new(:$tree);

    Grammar.parse($src, :$actions);
    Renderer.render($actions.tree);
  }
}
