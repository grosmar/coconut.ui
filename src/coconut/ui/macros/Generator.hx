package coconut.ui.macros;

#if macro
import tink.hxx.StringAt;
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type;
import tink.hxx.Node;
import tink.anon.Macro.Part;


using tink.MacroApi;
using tink.CoreApi;

class Generator extends tink.hxx.Generator {
  
  override function complexAttribute(n:Node) 
    return unboxValues(super.complexAttribute(n));

  static function unboxValues(f:Option<Type>->Expr):Option<Type>->Expr 
    return function (expected:Option<Type>) return {
      switch expected {
        case Some(TAbstract(_.get() => { module: 'coconut.data.Value' }, [t])):
          f(Some(t));
        default: 
          f(expected);
      }
    }  

  override function makeAttribute(name:StringAt, value:Expr):Part {
    var ret = super.makeAttribute(name, value);
    @:privateAccess ret.getValue = unboxValues(ret.getValue);
    return ret;
  } 

  override function instantiate(name:StringAt, isClass:Bool, key:Option<Expr>, attr:Expr, children:Option<Expr>)
    return {
      var init = macro $i{name.value}.__init;
      if (init.typeof().isSuccess())
        macro @:pos(name.pos) coconut.ui.tools.ViewCache.mk(
          $v{Context.getType(name.value).getID()},
          ${key.or(macro null)},
          $init,
          $attr
        );
      else      
        super.instantiate(name, isClass, key, attr, children);
    }  
}
#end