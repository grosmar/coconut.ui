package coconut.ui.macros;

#if macro 
import haxe.macro.Context;
import haxe.macro.Type;
import haxe.macro.Expr;

using haxe.macro.Tools;
using tink.MacroApi;
using StringTools;

typedef Options = {
  var child(default, null):ComplexType;
  @:optional var customAttributes(default, null):String;
  @:optional var flatten(default, null):Expr->Expr;
}
#end

class HXX {
  #if macro
  static public var options:Options;
  static public function parse(e:Expr) {

    if (options == null)
      e.reject('Either the renderer did not configure HXX properly, or no renderer is used');

    var ret = 
      tink.hxx.Parser.parse(
        e, 
        {
          child: options.child,
          customAttributes: options.customAttributes,
          flatten: if (Reflect.hasField(options, 'flatten')) options.flatten else null,
          merger: macro coconut.ui.macros.HXX.merge,
        }, 
        { defaultExtension: 'hxx', noControlStructures: false, defaultSwitchTarget: macro __data__ }
      );

    return 
      if ((macro this.__cachedModelView).typeof().isSuccess()) cached(ret);
      else ret;
  }
  static function cached(e:Expr) 
    return switch e.map(cached) {
      case { expr: ENew(cl, [a]), pos: pos }:
        
        var path = cl.pack.copy();
        path.push(cl.name);

        switch cl.sub {
          case null: '';
          case v: path.push(v);
        }

        var name = path.join('.');

        if (Context.getType(name).isSubTypeOf(Context.getType('coconut.ui.tools.ModelView')).isSuccess())
          macro __cachedModelView($a, $v{name}, $p{path}.new);
        else
          throw 'not implemented';
        // ENew(cl, args).at(pos).log();
      case v: v;
    }    
  #end

  macro static public function observable(e:Expr) {
    var blank = e.pos.makeBlankType();
    
    function checkConst(t:TypedExpr) {
      switch t.expr {
        case TCall({ expr: TField(_, f) }, _):
          switch f {
            case FEnum(_, _):
              
            default:
              throw false;  
          } 
        case TCall(_, _): 
          throw false;
        case TField(_, FEnum(_, _)):
        case TField(_, FInstance(_, _, f) | FStatic(_, f) | FAnon(f)):
          switch f.get().kind {
            case FMethod(_):
            case FVar(_, AccNever | AccInline):
            default:
              throw false;
          }
        case TField(_, _):
          throw false;
        default:
          
      }
      t.iter(checkConst);
    }
    var t = Context.typeExpr(e);
    return
      try {
        checkConst(t);
        // trace(e.toString());
        // trace(t.toString());
        Context.storeTypedExpr(t);
      }
      catch (error:Bool) 
        try 
          Context.storeTypedExpr(Context.typeExpr(macro @:pos(e.pos) ($e : tink.state.Observable.ObservableObject<$blank>)))
        catch (_:Dynamic) 
          macro @:pos(e.pos) tink.state.Observable.auto(function () return $e);
  }


  macro static public function merge(primary:Expr, rest:Array<Expr>)
    return tink.hxx.Merge.mergeObjects(primary, rest, {
      fixField: function (e) return e,
      genField: function (ctx) {
        return
          if (ctx.expected.reduce().toString().startsWith('tink.state.Observable<')) {
            var ct = ctx.expected.toComplex();
            var e = ctx.original;
            macro @:pos(e.pos) (coconut.ui.macros.HXX.observable($e) : $ct);
          }
          else ctx.getDefault();
      },
      decomposeSingle: function (src, expected, decompose) {
        return
          switch expected.reduce() {
            case TAnonymous(_.get().fields => fields):              
              return 
                if ((macro ($src : coconut.data.Model)).typeof().isSuccess()) {
                  var parts = [macro __model__, macro { key: __model__ }];
                  macro {
                    var __model__ = $src;
                    ${decompose.bind(parts).bounce()};
                  }
                }
                else decompose([src]);
            default: src;
          }
      },
    });

  macro static public function hxx(e:Expr)
    return parse(e);
}