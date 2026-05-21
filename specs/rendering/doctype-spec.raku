use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::X;

describe 'doctype declarations', {
  it '!!! 5 renders HTML5 doctype', {
    expect(HAML.render(:src("!!! 5\n"))).to.eq("<!DOCTYPE html>\n");
  }

  it '!!! with no arg defaults to HTML5 doctype', {
    expect(HAML.render(:src("!!!\n"))).to.eq("<!DOCTYPE html>\n");
  }

  it '!!! 1.1 renders XHTML 1.1', {
    expect(HAML.render(:src("!!! 1.1\n"))).to.eq(
      '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">' ~ "\n"
    );
  }

  it '!!! Strict renders XHTML 1.0 Strict', {
    expect(HAML.render(:src("!!! Strict\n"))).to.eq(
      '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">' ~ "\n"
    );
  }

  it '!!! Frameset renders XHTML 1.0 Frameset', {
    expect(HAML.render(:src("!!! Frameset\n"))).to.eq(
      '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd">' ~ "\n"
    );
  }

  it '!!! Mobile renders XHTML Mobile 1.2', {
    expect(HAML.render(:src("!!! Mobile\n"))).to.eq(
      '<!DOCTYPE html PUBLIC "-//WAPFORUM//DTD XHTML Mobile 1.2//EN" "http://www.openmobilealliance.org/tech/DTD/xhtml-mobile12.dtd">' ~ "\n"
    );
  }

  it '!!! RDFa renders XHTML+RDFa 1.0', {
    expect(HAML.render(:src("!!! RDFa\n"))).to.eq(
      '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">' ~ "\n"
    );
  }

  it '!!! Basic renders XHTML Basic 1.1', {
    expect(HAML.render(:src("!!! Basic\n"))).to.eq(
      '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.1//EN" "http://www.w3.org/TR/xhtml-basic/xhtml-basic11.dtd">' ~ "\n"
    );
  }

  it '!!! XML defaults to utf-8', {
    expect(HAML.render(:src("!!! XML\n"))).to.eq("<?xml version='1.0' encoding='utf-8' ?>\n");
  }

  it '!!! XML iso-8859-1 uses custom encoding', {
    expect(HAML.render(:src("!!! XML iso-8859-1\n"))).to.eq("<?xml version='1.0' encoding='iso-8859-1' ?>\n");
  }

  it 'renders doctype before the first tag', {
    expect(HAML.render(:src("!!! 5\n%html\n"))).to.eq("<!DOCTYPE html>\n<html></html>\n");
  }

  it 'raises X::HAML::UnknownDoctype on unknown variant', {
    expect({ HAML.render(:src("!!! Bogus\n")) }).to.raise-error(X::HAML::UnknownDoctype);
  }

  it 'raises X::HAML::DoctypeNotFirst when doctype follows content', {
    expect({ HAML.render(:src("%p hi\n!!! 5\n")) }).to.raise-error(X::HAML::DoctypeNotFirst);
  }
}
