
use Template::Haml::Node;

class Tree is export {
  has Node $.root;

  submethod BUILD {
    $!root = Node.new;
  }
}
