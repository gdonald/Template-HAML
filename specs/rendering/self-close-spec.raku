use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::X;

describe 'self-closing tags', {
  it 'explicit %br/ self-closes (HTML5)', {
    expect(HAML.render(:src("%br/\n"))).to.eq("<br>\n");
  }

  it 'explicit %img/ self-closes (HTML5)', {
    expect(HAML.render(:src("%img/\n"))).to.eq("<img>\n");
  }

  it '%br auto self-closes (void element)', {
    expect(HAML.render(:src("%br\n"))).to.eq("<br>\n");
  }

  it '%img auto self-closes (void element)', {
    expect(HAML.render(:src("%img\n"))).to.eq("<img>\n");
  }

  it '%hr auto self-closes (void element)', {
    expect(HAML.render(:src("%hr\n"))).to.eq("<hr>\n");
  }

  it '%input{type:...} auto self-closes with attrs', {
    expect(HAML.render(:src("%input\{type: 'text'\}\n"))).to.eq("<input type='text'>\n");
  }

  it '%div is NOT void - still gets close tag', {
    expect(HAML.render(:src("%div\n"))).to.eq("<div></div>\n");
  }

  it 'void element with children dies', {
    expect({ HAML.render(:src("%br\n  %span hi\n")) }).to.raise-error(X::HAML::VoidWithChildren);
  }
}
