use lib 'lib';
use BDD::Behave;
use Template::HAML::Actions;
use Template::HAML::Grammar;
use Template::HAML::Node;
use Template::HAML::Renderer;

describe 'Grammar tag rule + Renderer', {
  it 'renders a %section.container as a section with a class', {
    my $tree = Node.new;
    $tree.add-child(Node.new);
    my $actions = Actions.new(:$tree);

    Grammar.parse("%section.container", :rule<tag>, :$actions);
    my $rendered = Renderer.new.render($actions.tree);
    expect($rendered).to.eq("<section class='container'></section>\n");
  }
}
