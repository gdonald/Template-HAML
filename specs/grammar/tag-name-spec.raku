use lib 'lib';
use BDD::Behave;
use Template::HAML;

describe 'tag names', {
  it 'allows : in a tag name for XML namespacing', {
    expect(HAML.render(:src("%xml:lang en\n")))
      .to.eq("<xml:lang>en</xml:lang>\n");
  }

  it 'allows - in a tag name for custom elements', {
    expect(HAML.render(:src("%my-component\n")))
      .to.eq("<my-component></my-component>\n");
  }

  it 'allows - mid-name with content', {
    expect(HAML.render(:src("%data-grid hi\n")))
      .to.eq("<data-grid>hi</data-grid>\n");
  }

  it 'dies when a tag name starts with a digit', {
    expect({ HAML.render(:src("%1abc\n")) }).to.raise-error;
  }

  it 'dies on a single-digit tag name', {
    expect({ HAML.render(:src("%9\n")) }).to.raise-error;
  }
}
