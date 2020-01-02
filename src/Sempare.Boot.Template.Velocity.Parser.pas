(*%****************************************************************************
 *  ___                                             ___               _       *
 * / __|  ___   _ __    _ __   __ _   _ _   ___    | _ )  ___   ___  | |_     *
 * \__ \ / -_) | '  \  | '_ \ / _` | | '_| / -_)   | _ \ / _ \ / _ \ |  _|    *
 * |___/ \___| |_|_|_| | .__/ \__,_| |_|   \___|   |___/ \___/ \___/  \__|    *
 *                     |_|                                                    *
 ******************************************************************************
 *                                                                            *
 *                        VELOCITY TEMPLATE ENGINE                            *
 *                                                                            *
 *                                                                            *
 *          https://www.github.com/sempare/sempare.boot.velocity.oss          *
 ******************************************************************************
 *                                                                            *
 * Copyright (c) 2019 Sempare Limited,                                        *
 *                    Conrad Vermeulen <conrad.vermeulen@gmail.com>           *
 *                                                                            *
 * Contact: info@sempare.ltd                                                  *
 *                                                                            *
 * Licensed under the Apache License, Version 2.0 (the "License");            *
 * you may not use this file except in compliance with the License.           *
 * You may obtain a copy of the License at                                    *
 *                                                                            *
 *   http://www.apache.org/licenses/LICENSE-2.0                               *
 *                                                                            *
 * Unless required by applicable law or agreed to in writing, software        *
 * distributed under the License is distributed on an "AS IS" BASIS,          *
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   *
 * See the License for the specific language governing permissions and        *
 * limitations under the License.                                             *
 *                                                                            *
 ****************************************************************************%*)
unit Sempare.Boot.Template.Velocity.Parser;

interface

uses
  System.Classes,
  Sempare.Boot.Template.Velocity.AST,
  Sempare.Boot.Template.Velocity.Context;

type
  IVelocityParser = interface
    ['{DAF8A08D-9158-4D2C-9E76-BE80E9DA50A3}']

    function Parse(const AStream: TStream; const AManagedStream: boolean = true): IVelocityTemplate;
  end;

function CreateVelocityParser(Const AContext: IVelocityContext): IVelocityParser;

implementation

uses
  System.SysUtils,
  System.Math,
  System.Rtti,
  System.Generics.Collections,
  Sempare.Boot.Template.Velocity,
  Sempare.Boot.Template.Velocity.Evaluate,
  Sempare.Boot.Template.Velocity.Common,
  Sempare.Boot.Template.Velocity.Lexer,
  Sempare.Boot.Template.Velocity.Rtti,
  Sempare.Boot.Template.Velocity.Util;

type

  TTemplate = class(TInterfacedObject, IVelocityTemplate, ITemplateAdd, IVelocityVisitorHost)
  private
    FArray: TArray<IVelocityVisitorHost>;
    function GetItem(const AOffset: integer): IVelocityVisitorHost;
    function GetCount: integer;
    procedure Add(const AItem: IVelocityVisitorHost);
    function GetLastItem: IVelocityVisitorHost;

    procedure Accept(const AVisitor: IVelocityVisitor);
  public

  end;

  TAbstractBase = class abstract(TInterfacedObject, IPositional, IVelocityVisitorHost)
  private
    FPosition: IPosition;
    function GetPosition: IPosition;
  public
    constructor Create(const APosition: IPosition);
    destructor Destroy; override;
    procedure Accept(const AVisitor: IVelocityVisitor); virtual; abstract;
  end;

  TAbstractStmt = class abstract(TAbstractBase, IStmt)
  end;

  TEndStmt = class(TAbstractStmt, IEndStmt)
  private
    procedure Accept(const AVisitor: IVelocityVisitor); override;
  end;

  TElseStmt = class(TAbstractStmt, IElseStmt)
  private
    procedure Accept(const AVisitor: IVelocityVisitor); override;
  end;

  TContinueStmt = class(TAbstractStmt, IContinueStmt)
  private
    procedure Accept(const AVisitor: IVelocityVisitor); override;
  end;

  TBreakStmt = class(TAbstractStmt, IBreakStmt)
  private
    procedure Accept(const AVisitor: IVelocityVisitor); override;
  end;

  TCommentStmt = class(TAbstractStmt, ICommentStmt)
  private
    procedure Accept(const AVisitor: IVelocityVisitor); override;
  end;

  TElIfStmt = class(TAbstractStmt, IElIfStmt)
  private
    procedure Accept(const AVisitor: IVelocityVisitor); override;
  end;

  TPrintStmt = class(TAbstractStmt, IPrintStmt)
  private
    FExpr: IExpr;
    function GetExpr: IExpr; inline;
    procedure Accept(const AVisitor: IVelocityVisitor); override;
  public
    constructor Create(const APosition: IPosition; const AExpr: IExpr);
  end;

  TIncludeStmt = class(TAbstractStmt, IIncludeStmt)
  private
    FExpr: IExpr;
    function GetExpr: IExpr; inline;
    procedure Accept(const AVisitor: IVelocityVisitor); override;
  public
    constructor Create(const APosition: IPosition; const AExpr: IExpr);
  end;

  TIfStmt = class(TAbstractStmt, IIfStmt)
  private
    FCondition: IExpr;
    FTrueContainer: IVelocityTemplate;
    FFalseContainer: IVelocityTemplate;
    function GetCondition: IExpr; inline;
    function GetTrueContainer: IVelocityTemplate; inline;
    function GetFalseContainer: IVelocityTemplate; inline;

    procedure Accept(const AVisitor: IVelocityVisitor); override;
  public
    constructor Create(const APosition: IPosition; const ACondition: IExpr; const ATrueContainer: IVelocityTemplate; const AFalseContainer: IVelocityTemplate);
  end;

  TProcessTemplateStmt = class(TAbstractStmt, IProcessTemplateStmt)
  private
    FContainer: IVelocityTemplate;
    function GetContainer: IVelocityTemplate;

    procedure Accept(const AVisitor: IVelocityVisitor); override;
  public
    constructor Create(const APosition: IPosition; const AContainer: IVelocityTemplate);
  end;

  TDefineTemplateStmt = class(TAbstractStmt, IDefineTemplateStmt)
  private
    FName: IExpr;
    FContainer: IVelocityTemplate;
    function GetName: IExpr;
    function GetContainer: IVelocityTemplate;

    procedure Accept(const AVisitor: IVelocityVisitor); override;
  public
    constructor Create(const APosition: IPosition; const AName: IExpr; const AContainer: IVelocityTemplate);
  end;

  TWithStmt = class(TAbstractStmt, IWithStmt)
  private
    FExpr: IExpr;
    FContainer: IVelocityTemplate;
    function GetContainer: IVelocityTemplate;
    function GetExpr: IExpr; inline;
    procedure Accept(const AVisitor: IVelocityVisitor); override;

  public
    constructor Create(const APosition: IPosition; const AExpr: IExpr; const AContainer: IVelocityTemplate);
  end;

  TWhileStmt = class(TAbstractStmt, IWhileStmt)
  private
    FCondition: IExpr;
    FContainer: IVelocityTemplate;
    function GetCondition: IExpr; inline;
    function GetContainer: IVelocityTemplate; inline;
    procedure Accept(const AVisitor: IVelocityVisitor); override;

  public
    constructor Create(const APosition: IPosition; const ACondition: IExpr; const AContainer: IVelocityTemplate);
  end;

  TForInStmt = class(TAbstractStmt, IForInStmt)
  private
    FVariable: string;
    FExpr: IExpr;
    FContainer: IVelocityTemplate;
    function GetVariable: string; inline;
    function GetExpr: IExpr; inline;
    function GetContainer: IVelocityTemplate; inline;
    procedure Accept(const AVisitor: IVelocityVisitor); override;

  public
    constructor Create(const APosition: IPosition; const AVariable: string; const AExpr: IExpr; const AContainer: IVelocityTemplate);
  end;

  TForRangeStmt = class(TAbstractStmt, IForRangeStmt)
  private
    FVariable: string;
    FForIp: TForOp;
    FLowExpr: IExpr;
    FHighExpr: IExpr;
    FContainer: IVelocityTemplate;
    function GetVariable: string; inline;
    function GetForOp: TForOp; inline;
    function GetLowExpr: IExpr; inline;
    function GetHighExpr: IExpr; inline;
    function GetContainer: IVelocityTemplate; inline;
    procedure Accept(const AVisitor: IVelocityVisitor); override;

  public
    constructor Create(const APosition: IPosition; const AVariable: string; const AForIp: TForOp; const ALowExpr: IExpr; const AHighExpr: IExpr; const AContainer: IVelocityTemplate);
  end;

  TAssignStmt = class(TAbstractStmt, IAssignStmt)
  private
    FVariable: string;
    FExpr: IExpr;
    function GetVariable: string; inline;
    function GetExpr: IExpr; inline;
    procedure Accept(const AVisitor: IVelocityVisitor); override;

  public
    constructor Create(const APosition: IPosition; const AVariable: string; const AExpr: IExpr);
  end;

  TExprList = class(TAbstractBase, IExprList)
  private
    FExprs: TArray<IExpr>;
    function GetExpr(const AOffset: integer): IExpr; inline;
    procedure AddExpr(const AExpr: IExpr);
    function GetExprCount: integer; inline;
    procedure Accept(const AVisitor: IVelocityVisitor); override;
  public
  end;

  TAbstractExpr = class abstract(TAbstractBase, IExpr)
  end;

  TValueExpr = class(TAbstractExpr, IValueExpr)
  private
    FValue: TValue;
    function GetValue: TValue; inline;
    procedure Accept(const AVisitor: IVelocityVisitor); override;

  public
    constructor Create(const APosition: IPosition; const AValue: TValue);
  end;

  TArrayExpr = class(TAbstractExpr, IArrayExpr)
  private
    FValue: IExprList;
    function GetValue: IExprList;
    procedure Accept(const AVisitor: IVelocityVisitor); override;

  public
    constructor Create(const APosition: IPosition; const AValue: IExprList);
  end;

  TVariableExpr = class(TAbstractExpr, IVariableExpr)
  private
    FVariable: string;
    function GetVariable: string; inline;
    procedure Accept(const AVisitor: IVelocityVisitor); override;
  public
    constructor Create(const APosition: IPosition; const AVariable: string);
  end;

  TEncodeExpr = class(TAbstractExpr, IEncodeExpr)
  private
    FExpr: IExpr;
    function GetExpr: IExpr; inline;
    procedure Accept(const AVisitor: IVelocityVisitor); override;
  public
    constructor Create(const APosition: IPosition; const AExpr: IExpr);
  end;

  TVariableDerefExpr = class(TAbstractExpr, IVariableDerefExpr)
  private
    FVariable: IExpr;
    FDeref: IExpr;
    FDerefType: TDerefType;
    function GetDerefType: TDerefType;
    function GetVariable: IExpr; inline;
    function GetDerefExpr: IExpr; inline;
    procedure Accept(const AVisitor: IVelocityVisitor); override;
  public
    constructor Create(const APosition: IPosition; const ADerefType: TDerefType; const AVariable: IExpr; const ADeref: IExpr);
  end;

  TFunctionCallExpr = class(TAbstractExpr, IFunctionCallExpr)
  private
    FFunctionInfo: TArray<TRttiMethod>;
    FExprList: IExprList;

    function GetFunctionInfo: TArray<TRttiMethod>; inline;
    function GetExprList: IExprList; inline;
    procedure Accept(const AVisitor: IVelocityVisitor); override;

  public
    constructor Create(const APosition: IPosition; AFunction: TArray<TRttiMethod>; const ExprList: IExprList);
  end;

  TMethodCallExpr = class(TAbstractExpr, IMethodCallExpr)
  private
    FObjectExpr: IExpr;
    FMethod: string;
    FExprList: IExprList;
    FRttiMethod: TRttiMethod;

    function GetMethod: string; inline;
    function GetObject: IExpr; inline;
    function GetExprList: IExprList; inline;
    function GetRttiMethod: TRttiMethod;
    procedure SetRttiMethod(const ARttiMethod: TRttiMethod);

    procedure Accept(const AVisitor: IVelocityVisitor); override;

  public
    constructor Create(const APosition: IPosition; const AObjectExpr: IExpr; const AMethod: string; const AExprList: IExprList);
  end;

  TBinopExpr = class(TAbstractExpr, IBinopExpr)
  private
    FLeft: IExpr;
    FBinop: TBinOp;
    FRight: IExpr;
    function GetBinOp: TBinOp; inline;
    function GetLeftExpr: IExpr; inline;
    function GetRightExpr: IExpr; inline;
    procedure Accept(const AVisitor: IVelocityVisitor); override;

  public
    constructor Create(const APosition: IPosition; const ALeft: IExpr; const ABinop: TBinOp; const ARight: IExpr);
    destructor Destroy; override;
  end;

  TTernaryExpr = class(TAbstractExpr, ITernaryExpr)
  private
    FCondition: IExpr;
    FTrueExpr: IExpr;
    FFalseExpr: IExpr;
    function GetCondition: IExpr; inline;
    function GetTrueExpr: IExpr; inline;
    function GetFalseExpr: IExpr; inline;

    procedure Accept(const AVisitor: IVelocityVisitor); override;
  public
    constructor Create(const APosition: IPosition; const ACondition: IExpr; const ATrueExpr: IExpr; const AFalseExpr: IExpr);
  end;

  TUnaryExpr = class(TAbstractExpr, IUnaryExpr)
  private
    FUnaryOp: TUnaryOp;
    FExpr: IExpr;
    function GetExpr: IExpr; inline;
    function GetUnaryOp: TUnaryOp; inline;
    procedure Accept(const AVisitor: IVelocityVisitor); override;

  public
    constructor Create(const APosition: IPosition; const AUnaryOp: TUnaryOp; const AExpr: IExpr);

  end;

  EEndOfBlock = class(Exception);

  TVelocitySymbolSet = set of TVelocitySymbol;

  TParserOption = (poAllowEnd, poAllowElse, poAllowElIf, poHasElse, poInLoop);
  TParserOptions = set of TParserOption;

  TVelocityParser = class(TInterfacedObject, IVelocityParser)
  private
    FContext: IVelocityContext;
    FLookahead: IvelocitySymbol;
    FLexer: IVelocityLexer;
    FContainerStack: TStack<IVelocityTemplate>;
    FOptions: TParserOptions;

    function PushContainer: IVelocityTemplate;
    function PopContainer: IVelocityTemplate;
    function CurrentContainer: IVelocityTemplate; inline;

    function LookaheadValue: string;
    function matchValue(const ASymbol: TVelocitySymbol): string;
    procedure match(const ASymbol: TVelocitySymbol);
    function MatchNumber(const ASymbol: TVelocitySymbol): extended;

  private
    procedure RuleStmts(const Container: IVelocityTemplate; const AEndToken: TVelocitySymbolSet);
    function RuleStmt(): IStmt;
    function RuleCommentStmt: IStmt;
    function ruleIdStmt: IStmt;
    function ruleExprStmt: IStmt;
    function ruleIncludeStmt: IStmt;
    function RulePrintStmt: IStmt;
    function ruleEndStmt: IStmt;
    function ruleContinueStmt: IStmt;
    function ruleBreakStmt: IStmt;
    function RuleIfStmt: IStmt;
    function RuleElIfStmt: IStmt;
    function RuleExprList(const AEndToken: TVelocitySymbol = VsCloseRoundBracket): IExprList;
    function RuleAssignStmt(const ASymbol: IExpr): IStmt;
    function RulePrintStmtVariable(const AExpr: IExpr): IStmt; overload;
    function RuleForStmt: IStmt;
    function RuleWhileStmt: IStmt;
    function RuleWithStmt: IStmt;
    function RuleTemplateStmt: IStmt;
    function RuleExpr(const minPrec: integer = 0): IExpr;
    function RulePrimaryExpr: IExpr;
    function RuleLiteralExpr: IExpr;
    function RuleIdentifierExpr: IExpr;
    function ruleFunctionExpr(const ASymbol: string): IExpr;
    function ruleMethodExpr(const AExpr: IExpr; const AMethodExpr: IExpr): IExpr;
  public
    constructor Create(Const AContext: IVelocityContext);
    destructor Destroy; override;
    function Parse(const AStream: TStream; const AManagedStream: boolean): IVelocityTemplate;
  end;

function IsValue(const AExpr: IExpr): boolean;
begin
  result := supports(AExpr, IValueExpr);
end;

function AsValue(const AExpr: IExpr): TValue;
var
  v: IValueExpr;
begin
  AExpr.QueryInterface(IValueExpr, v);
  result := v.Value;
end;

function AsVarString(const AExpr: IExpr): string; inline;
begin
  result := (AExpr as IVariableExpr).Variable;
end;

function IsEnd(const AStmt: IStmt): boolean;
begin
  if AStmt = nil then
    exit(false);
  result := supports(AStmt, IEndStmt);
end;

function VelocityForop(const ASymbol: TVelocitySymbol): TForOp;

begin
  case ASymbol of
    vsTo:
      result := foTo;
    vsDownto:
      result := foDownto;
    vsin:
      result := foIn;
  else
    raise EParserError.Createfmt('Forop not supported: %s', [VelocitySymbolToString(ASymbol)]);
  end;
end;

const
  pInvalid: byte = 255;

var
  GVelocityBinOps: array [TVelocitySymbol] of TBinOp;
  GBinopPrecedents: array [TBinOp] of byte;

function VelocityBinop(const ASymbol: TVelocitySymbol; out BinOp: TBinOp): boolean;

begin
  BinOp := GVelocityBinOps[ASymbol];
  result := BinOp <> boInvalid;
end;

function GetVelocityParser(Const AContext: IVelocityContext): IVelocityParser;
begin
  result := TVelocityParser.Create(AContext);
end;

{ TVelocityParser }

constructor TVelocityParser.Create(Const AContext: IVelocityContext);
begin
  FOptions := [];
  FContext := AContext;
  FContainerStack := TStack<IVelocityTemplate>.Create;
end;

function TVelocityParser.RuleIdentifierExpr: IExpr;
var
  sym: IvelocitySymbol;

function Inspect(const AExpr: IExpr): IExpr; forward;

  function matchFunction(const AExpr: IExpr): IExpr;
  begin
    result := Inspect(ruleFunctionExpr(AsVarString(AExpr)));
  end;

  function matchArrayDeref(const AExpr: IExpr): IExpr;
  var
    idxExpr: IExpr;
  begin
    match(VsOpenSquareBracket);
    idxExpr := RuleExpr;
    result := TVariableDerefExpr.Create(sym.Position, dtArray, AExpr, idxExpr);
    match(VsCloseSquareBracket);

    if (eoEvalVarsEarly in FContext.Options) and IsValue(AExpr) and IsValue(idxExpr) then
      result := TValueExpr.Create(sym.Position, deref(AsValue(AExpr), AsValue(idxExpr)))
    else
      result := Inspect(result);
  end;

  function MatchDeref(const AExpr: IExpr): IExpr;
  var
    derefexpr: IExpr;
  begin
    // aexpr . id
    // aexpr . id ( )
    match(VsDOT);
    if FLookahead.Token = VsID then
    begin
      derefexpr := TVariableExpr.Create(sym.Position, matchValue(VsID));
      if FLookahead.Token = VsOpenRoundBracket then
        result := self.ruleMethodExpr(AExpr, derefexpr)
      else
      begin
        if (eoEvalVarsEarly in FContext.Options) and IsValue(AExpr) and IsValue(derefexpr) then
          result := TValueExpr.Create(sym.Position, deref(AsValue(AExpr), AsValue(derefexpr)))
        else
          result := TVariableDerefExpr.Create(sym.Position, dtObject, AExpr, derefexpr);
      end;

      exit(Inspect(result));
    end;
    RaiseError(Position(AExpr), 'Identified expected');
  end;

  function Inspect(const AExpr: IExpr): IExpr;
  begin
    case FLookahead.Token of
      VsOpenRoundBracket:
        result := matchFunction(AExpr);
      VsOpenSquareBracket:
        result := matchArrayDeref(AExpr);
      VsDOT:
        result := MatchDeref(AExpr);
    else
      result := AExpr;
    end;
  end;

var
  Variable: string;
  VarVal: TValue;

begin
  sym := FLookahead;
  Variable := matchValue(VsID);
  if (eoEvalVarsEarly in FContext.Options) and FContext.TryGetVariable(Variable, VarVal) then
    result := TValueExpr.Create(sym.Position, VarVal)
  else
    result := TVariableExpr.Create(sym.Position, Variable);
  result := Inspect(result);
end;

const
  IF_ELIF_END: TVelocitySymbolSet = [VsELIF, vsElse, vsEND];
  IF_END: TVelocitySymbolSet = [vsElse, vsEND];

function TVelocityParser.RuleIfStmt: IStmt;
var
  Condition: IExpr;
  TrueContainer: IVelocityTemplate;
  FalseContainer: IVelocityTemplate;
  ContainerAdd: ITemplateAdd;
  Options: IPreserveValue<TParserOptions>;
  symbol: IvelocitySymbol;
begin
  // TODO: review parse time evaluation. if condition is false, then block can be excluded
  Options := Preseve.Value<TParserOptions>(FOptions, FOptions + [poAllowElse, poAllowEnd, poAllowElIf]);
  symbol := FLookahead;
  match(VsIF);
  Condition := RuleExpr;

  match(VsEndScript);
  // create new container for true condition
  PushContainer;
  TrueContainer := self.CurrentContainer;

  RuleStmts(TrueContainer, IF_ELIF_END);
  PopContainer;

  PushContainer;
  FalseContainer := self.CurrentContainer;
  FalseContainer.QueryInterface(ITemplateAdd, ContainerAdd);

  if FLookahead.Token = VsELIF then
  begin
    while (FLookahead.Token = VsELIF) do
    begin
      ContainerAdd.Add(AsVisitorHost(RuleElIfStmt()));
    end;
  end
  else if FLookahead.Token = vsElse then
  begin
    match(vsElse);
    match(VsEndScript);
    RuleStmts(FalseContainer, [vsEND]);

  end;
  PopContainer;
  match(vsEND);
  match(VsEndScript);

  if (eoEvalEarly in FContext.Options) and IsValue(Condition) then
  begin
    if AsBoolean(AsValue(Condition)) then
      result := TProcessTemplateStmt.Create(symbol.Position, TrueContainer)
    else if FalseContainer <> nil then
      result := TProcessTemplateStmt.Create(symbol.Position, FalseContainer);
  end
  else
    result := TIfStmt.Create(symbol.Position, Condition, TrueContainer, FalseContainer);
end;

function TVelocityParser.ruleIncludeStmt: IStmt;
var
  symbol: IvelocitySymbol;
  include: IExpr;
  scope: IExpr;
  Container: TTemplate;
begin
  symbol := FLookahead;
  match(vsInclude);
  match(VsOpenRoundBracket);
  include := self.RuleExpr;

  if FLookahead.Token = vsComma then
  begin
    match(vsComma);
    scope := self.RuleExpr;
  end;

  match(VsCloseRoundBracket);
  match(VsEndScript);

  if scope <> nil then
  begin
    Container := TTemplate.Create();
    Container.Add(TIncludeStmt.Create(symbol.Position, include));
    result := TWithStmt.Create(symbol.Position, scope, Container);
  end
  else
  begin
    result := TIncludeStmt.Create(symbol.Position, include);
  end;
end;

function TVelocityParser.RuleLiteralExpr: IExpr;
var
  symbol: IvelocitySymbol;
begin
  symbol := FLookahead;
  case FLookahead.Token of
    vsString:
      result := TValueExpr.Create(symbol.Position, matchValue(vsString));
    vsNumber:
      result := TValueExpr.Create(symbol.Position, MatchNumber(vsNumber));
    VsBoolean:
      result := TValueExpr.Create(symbol.Position, matchValue(VsBoolean) = 'true');
  else
    RaiseError(symbol.Position, 'Literal expected');
  end;
end;

function TVelocityParser.ruleMethodExpr(const AExpr: IExpr; const AMethodExpr: IExpr): IExpr;
var
  symbol: IvelocitySymbol;
begin
  symbol := FLookahead;
  match(VsOpenRoundBracket);
  result := TMethodCallExpr.Create(symbol.Position, AExpr, AsVarString(AMethodExpr), RuleExprList);
  match(VsCloseRoundBracket);
end;

procedure TVelocityParser.RuleStmts(const Container: IVelocityTemplate; const AEndToken: TVelocitySymbolSet);

var
  stmt: IStmt;
  parentContainer: ITemplateAdd;
  sym: IvelocitySymbol;
  loop: boolean;

  function AddPrintStmt: IStmt;
  var
    txt: string;
  begin
    txt := matchValue(VsText);
    if txt = '' then
      exit(nil);
    result := RulePrintStmtVariable(TValueExpr.Create(sym.Position, txt));
  end;

begin
  Container.QueryInterface(ITemplateAdd, parentContainer);
  loop := true;
  while loop do
  begin
    sym := FLookahead;
    if (sym.Token = VsEOF) or (sym.Token in AEndToken) then
      break;
    stmt := nil;
    case sym.Token of
      VsText:
        stmt := AddPrintStmt;
      VsStartScript:
        begin
          stmt := RuleStmt;
          if stmt = nil then
            loop := false;
        end;
    end;
    if (stmt <> nil) and not supports(stmt, IElseStmt) then
    begin
      parentContainer.Add(AsVisitorHost(stmt));
    end;
  end;
end;

function TVelocityParser.RuleTemplateStmt: IStmt;
var
  expr: IExpr;
  symbol: IvelocitySymbol;
  Options: IPreserveValue<TParserOptions>;
  Container: IVelocityTemplate;
begin
  Options := Preseve.Value<TParserOptions>(FOptions, FOptions + [poAllowEnd]);
  symbol := FLookahead;

  match(vstemplate);
  expr := RuleExpr;
  match(VsEndScript);
  PushContainer;
  Container := CurrentContainer;

  RuleStmts(CurrentContainer, [vsEND]);

  match(vsEND);
  match(VsEndScript);
  PopContainer;

  result := TDefineTemplateStmt.Create(symbol.Position, expr, Container);

end;

function TVelocityParser.RuleStmt: IStmt;
var
  symbol: IvelocitySymbol;
begin
  symbol := FLookahead;
  result := nil;
  match(VsStartScript);
  case FLookahead.Token of
    vsBreak:
      result := ruleBreakStmt;
    vsContinue:
      result := ruleContinueStmt;
    vsComment:
      result := RuleCommentStmt;
    vsInclude:
      result := ruleIncludeStmt;
    vsEND:
      result := ruleEndStmt;
    vsElse: // we don't do anything
      ;
    VsIF:
      result := RuleIfStmt;
    VsELIF: // we don't do anything
      ;
    VsFor:
      result := RuleForStmt;
    vsPrint:
      result := RulePrintStmt;
    vsWhile:
      result := RuleWhileStmt;
    vswith:
      result := RuleWithStmt;
    vstemplate:
      result := RuleTemplateStmt;
    VsID:
      result := ruleIdStmt;
  else
    result := ruleExprStmt;
  end;
end;

function TVelocityParser.RuleAssignStmt(const ASymbol: IExpr): IStmt;
var
  symbol: IvelocitySymbol;
begin
  symbol := FLookahead;
  match(VsCOLONEQ);
  result := TAssignStmt.Create(symbol.Position, (ASymbol as IVariableExpr).Variable, RuleExpr);
end;

function TVelocityParser.ruleBreakStmt: IStmt;
var
  symbol: IvelocitySymbol;
begin
  symbol := FLookahead;
  match(vsBreak);
  match(VsEndScript);
  if not(poInLoop in FOptions) then
    RaiseError(symbol.Position, 'Continue should be in a for/while Stmt');
  result := TBreakStmt.Create(symbol.Position);
end;

function TVelocityParser.RuleCommentStmt: IStmt;
var
  symbol: IvelocitySymbol;
begin
  symbol := FLookahead;
  match(vsComment);
  match(VsEndScript);
  result := TCommentStmt.Create(symbol.Position);
end;

function TVelocityParser.ruleContinueStmt: IStmt;
var
  symbol: IvelocitySymbol;
begin
  symbol := FLookahead;
  match(vsContinue);
  match(VsEndScript);
  if not(poInLoop in FOptions) then
    RaiseError(symbol.Position, 'Continue should be in a for/while Stmt');

  result := TContinueStmt.Create(symbol.Position);
end;

function TVelocityParser.RuleElIfStmt: IStmt;

var
  Condition: IExpr;
  TrueContainer: IVelocityTemplate;
  FalseContainer: IVelocityTemplate;

  Options: IPreserveValue<TParserOptions>;
var
  symbol: IvelocitySymbol;
begin
  symbol := FLookahead;
  if not(poAllowElIf in FOptions) then
    RaiseError(symbol.Position, 'ElIF expected');

  Options := Preseve.Value<TParserOptions>(FOptions, FOptions + [poAllowElse, poHasElse, poAllowEnd]);

  match(VsELIF);

  Condition := RuleExpr;

  match(VsEndScript);
  // create new container for true condition
  PushContainer;
  TrueContainer := self.CurrentContainer;

  RuleStmts(TrueContainer, IF_ELIF_END);
  PopContainer;

  if FLookahead.Token = vsElse then
  begin

    match(vsElse);
    match(VsEndScript);

    PushContainer;
    FalseContainer := self.CurrentContainer;

    RuleStmts(FalseContainer, [vsEND, VsELIF]);

    PopContainer;
  end;

  if (eoEvalEarly in FContext.Options) and IsValue(Condition) then
  begin
    if AsBoolean(AsValue(Condition)) then
      result := TProcessTemplateStmt.Create(symbol.Position, TrueContainer)
    else if FalseContainer <> nil then
      result := TProcessTemplateStmt.Create(symbol.Position, FalseContainer);
  end
  else
    result := TIfStmt.Create(symbol.Position, Condition, TrueContainer, FalseContainer);
end;

function TVelocityParser.ruleEndStmt: IStmt;
var
  symbol: IvelocitySymbol;
begin
  symbol := FLookahead;
  // NOTE: we do not match anything as we want lookahead functions to continue to work
  if not(poAllowEnd in FOptions) then
    RaiseError(symbol.Position, 'End not expected');
  result := TEndStmt.Create(symbol.Position);
end;

function TVelocityParser.RuleExpr(const minPrec: integer): IExpr;
var
  prec: integer;
  BinOp: TBinOp;
  symbol: IvelocitySymbol;
  right: IExpr;
  trueExpr, falseExpr: IExpr;
  evaluated: boolean;
begin
  symbol := FLookahead;
  result := self.RulePrimaryExpr;
  // this loop is a nicer way of applying precedents rather than having more rules like traditional factor, term, etc...
  while VelocityBinop(FLookahead.Token, BinOp) do
  begin
    prec := GBinopPrecedents[BinOp];
    if prec < minPrec then
      break;
    match(FLookahead.Token);
    right := self.RuleExpr(prec);
    evaluated := false;
    if (eoEvalEarly in FContext.Options) and IsValue(result) and IsValue(right) then
    begin
      evaluated := true;
      case BinOp of
        boAND:
          result := TValueExpr.Create(symbol.Position, AsBoolean(AsValue(result)) and AsBoolean(AsValue(right)));
        boOR:
          result := TValueExpr.Create(symbol.Position, AsBoolean(AsValue(result)) or AsBoolean(AsValue(right)));
        boPlus:
          begin
            if isNumLike(AsValue(result)) and isNumLike(AsValue(right)) then
              result := TValueExpr.Create(symbol.Position, asnum(AsValue(result)) + asnum(AsValue(right)))
            else if isStrLike(AsValue(result)) and isStrLike(AsValue(right)) then
              result := TValueExpr.Create(symbol.Position, asString(AsValue(result)) + asString(AsValue(right)))
            else if isStrLike(AsValue(result)) and isNumLike(AsValue(right)) then
              result := TValueExpr.Create(symbol.Position, asString(AsValue(result)) + floattostr(asnum(AsValue(right))))
            else
              RaiseError(symbol.Position, 'Evaluation not supported.');
          end;
        boMinus:
          result := TValueExpr.Create(symbol.Position, asnum(AsValue(result)) - asnum(AsValue(right)));
        boMult:
          result := TValueExpr.Create(symbol.Position, asnum(AsValue(result)) * asnum(AsValue(right)));
        boDiv:
          result := TValueExpr.Create(symbol.Position, asnum(AsValue(result)) / asnum(AsValue(right)));
        boMod:
          result := TValueExpr.Create(symbol.Position, AsInt(AsValue(result)) mod AsInt(AsValue(right)));
      else
        evaluated := false;
      end;
    end;
    if not evaluated then
      result := TBinopExpr.Create(symbol.Position, result, BinOp, right);
  end;

  if FLookahead.Token = vsQUESTION then
  begin
    match(vsQUESTION);
    trueExpr := self.RuleExpr();
    match(vsColon);
    falseExpr := self.RuleExpr();

    if (eoEvalEarly in FContext.Options) and IsValue(result) then
    begin
      if AsBoolean(AsValue(result)) then
        result := trueExpr
      else
        result := falseExpr;
    end
    else
      result := TTernaryExpr.Create(symbol.Position, result, trueExpr, falseExpr);
  end;

end;

function TVelocityParser.RuleForStmt: IStmt;
var
  id: string;
  range: IExpr;
  lowValue, highValue: IExpr;
  ForOp: TForOp;
  Options: IPreserveValue<TParserOptions>;
  Container: IVelocityTemplate;
var
  symbol: IvelocitySymbol;
begin
  symbol := FLookahead;
  Options := Preseve.Value<TParserOptions>(FOptions, FOptions + [poInLoop, poAllowEnd]);
  match(VsFor);
  PushContainer;
  Container := CurrentContainer;
  id := matchValue(VsID);
  if FLookahead.Token = vsin then
  begin
    ForOp := VelocityForop(FLookahead.Token);
    match(vsin);
    range := RuleExpr;
  end
  else
  begin
    match(VsCOLONEQ);
    lowValue := RuleExpr();
    ForOp := VelocityForop(FLookahead.Token);
    if FLookahead.Token in [vsDownto, vsTo] then
      match(FLookahead.Token)
    else
      RaiseError(symbol.Position, 'downto/to token expected in for loop.');
    highValue := RuleExpr();
  end;

  match(VsEndScript);

  RuleStmts(Container, [vsEND]);

  match(vsEND);
  match(VsEndScript);

  if ForOp = TForOp.foIn then
    result := TForInStmt.Create(symbol.Position, id, range, Container)
  else
    result := TForRangeStmt.Create(symbol.Position, id, ForOp, lowValue, highValue, Container);
  PopContainer;
end;

function TVelocityParser.ruleFunctionExpr(const ASymbol: string): IExpr;
var
  fn: TArray<TRttiMethod>;
  symbol: IvelocitySymbol;
begin
  symbol := FLookahead;
  if not FContext.TryGetFunction(ASymbol, fn) then
    RaiseError(symbol.Position, 'Function %s not registered in context.', [ASymbol]);
  match(VsOpenRoundBracket);
  result := TFunctionCallExpr.Create(symbol.Position, fn, RuleExprList);
  match(VsCloseRoundBracket);
end;

function TVelocityParser.ruleIdStmt: IStmt;
var
  symbol: IvelocitySymbol;
  expr: IExpr;
begin
  symbol := FLookahead;
  expr := self.RuleIdentifierExpr;
  if FLookahead.Token = VsCOLONEQ then
  begin
    result := RuleAssignStmt(expr);
  end
  else
  begin
    expr := TEncodeExpr.Create(symbol.Position, expr);
    result := RulePrintStmtVariable(expr);
  end;
  match(VsEndScript);
end;

function TVelocityParser.RuleWhileStmt: IStmt;
var
  Condition: IExpr;
  Options: IPreserveValue<TParserOptions>;
  symbol: IvelocitySymbol;
begin
  symbol := FLookahead;
  Options := Preseve.Value<TParserOptions>(FOptions, FOptions + [poInLoop, poAllowEnd]);
  PushContainer;

  match(vsWhile);
  Condition := RuleExpr;
  match(VsEndScript);

  RuleStmts(CurrentContainer, [vsEND]);

  match(vsEND);
  match(VsEndScript);

  if (eoEvalEarly in FContext.Options) and IsValue(Condition) and not AsBoolean(AsValue(Condition)) then
    result := nil
  else
    result := TWhileStmt.Create(symbol.Position, Condition, CurrentContainer);
  PopContainer;

end;

function TVelocityParser.RuleWithStmt: IStmt;
var
  expr: IExpr;
  symbol: IvelocitySymbol;
  Options: IPreserveValue<TParserOptions>;
  Container: IVelocityTemplate;
begin
  Options := Preseve.Value<TParserOptions>(FOptions, FOptions + [poAllowEnd]);

  symbol := FLookahead;

  match(vswith);
  expr := RuleExpr;
  match(VsEndScript);

  PushContainer;
  Container := CurrentContainer;

  RuleStmts(Container, [vsEND]);

  match(vsEND);
  match(VsEndScript);

  PopContainer;
  result := TWithStmt.Create(symbol.Position, expr, Container);

end;

function TVelocityParser.RulePrimaryExpr: IExpr;
var
  symbol: IvelocitySymbol;

begin
  symbol := FLookahead;
  case FLookahead.Token of
    VsOpenSquareBracket:
      begin
        match(VsOpenSquareBracket);
        result := TArrayExpr.Create(symbol.Position, RuleExprList(VsCloseSquareBracket));
        match(VsCloseSquareBracket);
      end;
    VsOpenRoundBracket:
      begin
        match(VsOpenRoundBracket);
        result := RuleExpr();
        match(VsCloseRoundBracket);
      end;
    VsMinus:
      begin
        match(VsMinus);
        result := RuleExpr;
        if (eoEvalEarly in FContext.Options) and IsValue(result) then
          result := TValueExpr.Create(symbol.Position, -asnum(AsValue(result)))
        else
          result := TUnaryExpr.Create(symbol.Position, uoMinus, result);
      end;
    vsNot:
      begin
        match(vsNot);
        result := RuleExpr;
        if (eoEvalEarly in FContext.Options) and IsValue(result) then
          result := TValueExpr.Create(symbol.Position, not AsBoolean(AsValue(result)))
        else
          result := TUnaryExpr.Create(symbol.Position, uoNot, result);
      end;
    VsID:
      result := RuleIdentifierExpr;
  else
    result := RuleLiteralExpr;
  end;
end;

function TVelocityParser.RulePrintStmt: IStmt;
var
  symbol: IvelocitySymbol;
begin
  symbol := FLookahead;
  match(vsPrint);
  result := TPrintStmt.Create(symbol.Position, RuleExpr);
end;

function TVelocityParser.RulePrintStmtVariable(const AExpr: IExpr): IStmt;
var
  symbol: IvelocitySymbol;
  val: IValueExpr;
begin
  symbol := FLookahead;
  if supports(AExpr, IValueExpr, val) and (asString(val.Value) = '') then
    exit(nil);
  result := TPrintStmt.Create(symbol.Position, AExpr);
end;

function TVelocityParser.RuleExprList(const AEndToken: TVelocitySymbol): IExprList;
var
  symbol: IvelocitySymbol;
begin
  symbol := FLookahead;
  result := TExprList.Create(symbol.Position);
  if FLookahead.Token <> AEndToken then
    result.AddExpr(RuleExpr);
  while FLookahead.Token = vsComma do
  begin
    match(vsComma);
    result.AddExpr(RuleExpr);
  end;
end;

function TVelocityParser.ruleExprStmt: IStmt;
var
  symbol: IvelocitySymbol;
begin
  symbol := FLookahead;
  result := RulePrintStmtVariable(TEncodeExpr.Create(symbol.Position, RuleExpr));
  match(VsEndScript);
end;

function TVelocityParser.CurrentContainer: IVelocityTemplate;
begin
  if FContainerStack.Count <> 0 then
    result := FContainerStack.Peek;
end;

destructor TVelocityParser.Destroy;
begin
  FContainerStack.Free;
  inherited;
end;

function TVelocityParser.LookaheadValue: string;
var
  val: IVelocityValueSymbol;
begin
  if FLookahead.QueryInterface(IVelocityValueSymbol, val) = 0 then
    result := val.Value
  else
    result := '';
end;

procedure TVelocityParser.match(const ASymbol: TVelocitySymbol);
var
  symbol: IvelocitySymbol;
begin
  symbol := FLookahead;
  if ASymbol = FLookahead.Token then
  begin
    FLookahead := FLexer.GetToken;
    exit;
  end;
  RaiseError(symbol.Position, format('Parsing error expecting %s', [VelocitySymbolToString(ASymbol)]));
end;

function TVelocityParser.MatchNumber(const ASymbol: TVelocitySymbol): extended;
begin
  result := strtofloat(matchValue(ASymbol));
end;

function TVelocityParser.matchValue(const ASymbol: TVelocitySymbol): string;
var
  symbol: IvelocitySymbol;
begin
  symbol := FLookahead;
  if ASymbol = FLookahead.Token then
  begin
    result := LookaheadValue;
    FLookahead := FLexer.GetToken;
    exit;
  end;
  RaiseError(symbol.Position, format('Parsing error expecting %s', [VelocitySymbolToString(ASymbol)]));
end;

function TVelocityParser.Parse(const AStream: TStream; const AManagedStream: boolean): IVelocityTemplate;
begin
  FContainerStack.Clear;
  PushContainer;
  FLexer := CreateVelocityLexer(FContext, AStream, '', AManagedStream);
  FLookahead := FLexer.GetToken;
  RuleStmts(CurrentContainer, []);
  match(VsEOF);
  result := CurrentContainer;
  if eoPrettyPrint in FContext.Options then
    writeln(Velocity.PrettyPrint(result));
end;

function TVelocityParser.PopContainer: IVelocityTemplate;
begin
  result := self.CurrentContainer;
  FContainerStack.Pop;
end;

function TVelocityParser.PushContainer: IVelocityTemplate;
begin
  result := CurrentContainer;
  FContainerStack.Push(TTemplate.Create());
end;

{ TValueExpr }

procedure TValueExpr.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

constructor TValueExpr.Create(const APosition: IPosition; const AValue: TValue);
begin
  inherited Create(APosition);
  FValue := AValue;
end;

function TValueExpr.GetValue: TValue;
begin
  result := FValue;
end;

{ TExprList }

procedure TExprList.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

procedure TExprList.AddExpr(const AExpr: IExpr);
begin
  insert(AExpr, FExprs, length(FExprs));
end;

function TExprList.GetExpr(const AOffset: integer): IExpr;
begin
  result := FExprs[AOffset];
end;

function TExprList.GetExprCount: integer;
begin
  result := length(FExprs);
end;

{ TUnaryExpr }

procedure TUnaryExpr.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

constructor TUnaryExpr.Create(const APosition: IPosition; const AUnaryOp: TUnaryOp; const AExpr: IExpr);
begin
  inherited Create(APosition);
  FUnaryOp := AUnaryOp;
  FExpr := AExpr;
end;

function TUnaryExpr.GetExpr: IExpr;
begin
  result := FExpr;
end;

function TUnaryExpr.GetUnaryOp: TUnaryOp;
begin
  result := FUnaryOp;
end;

{ TVariableExpr }

procedure TVariableExpr.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

constructor TVariableExpr.Create(const APosition: IPosition; const AVariable: string);
begin
  inherited Create(APosition);
  FVariable := AVariable;
end;

function TVariableExpr.GetVariable: string;
begin
  result := FVariable;
end;

{ TFunctionCallExpr }

procedure TFunctionCallExpr.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

constructor TFunctionCallExpr.Create(const APosition: IPosition; AFunction: TArray<TRttiMethod>; const ExprList: IExprList);

begin
  inherited Create(APosition);
  FFunctionInfo := AFunction;
  FExprList := ExprList;
end;

function TFunctionCallExpr.GetExprList: IExprList;
begin
  result := FExprList;
end;

function TFunctionCallExpr.GetFunctionInfo: TArray<TRttiMethod>;
begin
  result := FFunctionInfo;
end;

{ TIfStmt }

procedure TIfStmt.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

constructor TIfStmt.Create(const APosition: IPosition; const ACondition: IExpr; const ATrueContainer, AFalseContainer: IVelocityTemplate);
begin
  inherited Create(APosition);
  FCondition := ACondition;
  FTrueContainer := ATrueContainer;
  FFalseContainer := AFalseContainer;
end;

function TIfStmt.GetCondition: IExpr;
begin
  result := FCondition;
end;

function TIfStmt.GetFalseContainer: IVelocityTemplate;
begin
  result := FFalseContainer;
end;

function TIfStmt.GetTrueContainer: IVelocityTemplate;
begin
  result := FTrueContainer;
end;

{ TBinopExpr }

procedure TBinopExpr.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

constructor TBinopExpr.Create(const APosition: IPosition; const ALeft: IExpr; const ABinop: TBinOp; const ARight: IExpr);
begin
  inherited Create(APosition);
  FLeft := ALeft;
  FBinop := ABinop;
  FRight := ARight;
end;

destructor TBinopExpr.Destroy;
begin
  FLeft := nil;
  FRight := nil;
end;

function TBinopExpr.GetBinOp: TBinOp;
begin
  result := FBinop;
end;

function TBinopExpr.GetLeftExpr: IExpr;
begin
  result := FLeft;
end;

function TBinopExpr.GetRightExpr: IExpr;
begin
  result := FRight;
end;

{ TPrintStmt }

procedure TPrintStmt.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

constructor TPrintStmt.Create(const APosition: IPosition; const AExpr: IExpr);
begin
  inherited Create(APosition);
  FExpr := AExpr;
end;

function TPrintStmt.GetExpr: IExpr;
begin
  result := FExpr;
end;

{ TForInStmt }

procedure TForInStmt.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

constructor TForInStmt.Create(const APosition: IPosition; const AVariable: string; const AExpr: IExpr; const AContainer: IVelocityTemplate);
begin
  inherited Create(APosition);
  FVariable := AVariable;
  FExpr := AExpr;
  FContainer := AContainer;
end;

function TForInStmt.GetContainer: IVelocityTemplate;
begin
  result := FContainer;
end;

function TForInStmt.GetExpr: IExpr;
begin
  result := FExpr;
end;

function TForInStmt.GetVariable: string;
begin
  result := FVariable;
end;

{ TForRangeStmt }

procedure TForRangeStmt.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

constructor TForRangeStmt.Create(const APosition: IPosition; const AVariable: string; const AForIp: TForOp; const ALowExpr, AHighExpr: IExpr; const AContainer: IVelocityTemplate);
begin
  inherited Create(APosition);
  FVariable := AVariable;
  FForIp := AForIp;
  FLowExpr := ALowExpr;
  FHighExpr := AHighExpr;
  FContainer := AContainer;
end;

function TForRangeStmt.GetContainer: IVelocityTemplate;
begin
  result := FContainer;
end;

function TForRangeStmt.GetForOp: TForOp;
begin
  result := FForIp;
end;

function TForRangeStmt.GetHighExpr: IExpr;
begin
  result := FHighExpr;
end;

function TForRangeStmt.GetLowExpr: IExpr;
begin
  result := FLowExpr;
end;

function TForRangeStmt.GetVariable: string;
begin
  result := FVariable;
end;

{ TAssignStmt }

procedure TAssignStmt.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

constructor TAssignStmt.Create(const APosition: IPosition; const AVariable: string; const AExpr: IExpr);
begin
  inherited Create(APosition);
  FVariable := AVariable;
  FExpr := AExpr;
end;

function TAssignStmt.GetExpr: IExpr;
begin
  result := FExpr;
end;

function TAssignStmt.GetVariable: string;
begin
  result := FVariable;
end;

{ TTemplateContainer }

procedure TTemplate.Accept(const AVisitor: IVelocityVisitor);
var
  i: IVelocityVisitorHost;
begin
  for i in FArray do
    i.Accept(AVisitor);
end;

procedure TTemplate.Add(const AItem: IVelocityVisitorHost);
begin
  insert(AItem, FArray, length(FArray));
end;

function TTemplate.GetCount: integer;
begin
  result := length(FArray)
end;

function TTemplate.GetLastItem: IVelocityVisitorHost;
begin
  if GetCount = 0 then
    exit(nil);
  result := GetItem(GetCount - 1);
end;

function TTemplate.GetItem(const AOffset: integer): IVelocityVisitorHost;
begin
  result := FArray[AOffset];
end;

{ TWhileStmt }

procedure TWhileStmt.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

constructor TWhileStmt.Create(const APosition: IPosition; const ACondition: IExpr; const AContainer: IVelocityTemplate);
begin
  inherited Create(APosition);
  FCondition := ACondition;
  FContainer := AContainer;
end;

function TWhileStmt.GetCondition: IExpr;
begin
  result := FCondition;
end;

function TWhileStmt.GetContainer: IVelocityTemplate;
begin
  result := FContainer;
end;

{ TContinueStmt }

procedure TContinueStmt.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

{ TBreakStmt }

procedure TBreakStmt.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

{ TEndStmt }

procedure TEndStmt.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

{ TVariableDerefExpr }

procedure TVariableDerefExpr.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

constructor TVariableDerefExpr.Create(const APosition: IPosition; const ADerefType: TDerefType; const AVariable: IExpr; const ADeref: IExpr);
begin
  inherited Create(APosition);
  FDerefType := ADerefType;
  FVariable := AVariable;
  FDeref := ADeref;
end;

function TVariableDerefExpr.GetDerefExpr: IExpr;
begin
  result := FDeref;
end;

function TVariableDerefExpr.GetDerefType: TDerefType;
begin
  result := FDerefType;
end;

function TVariableDerefExpr.GetVariable: IExpr;
begin
  result := FVariable;
end;

{ TIncludeStmt }

procedure TIncludeStmt.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

constructor TIncludeStmt.Create(const APosition: IPosition; const AExpr: IExpr);
begin
  inherited Create(APosition);
  FExpr := AExpr;
end;

function TIncludeStmt.GetExpr: IExpr;
begin
  result := FExpr;
end;

function CreateVelocityParser(Const AContext: IVelocityContext): IVelocityParser;
begin
  result := TVelocityParser.Create(AContext);
end;

{ TElseStmt }

procedure TElseStmt.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

{ TElIfStmt }

procedure TElIfStmt.Accept(const AVisitor: IVelocityVisitor);
begin
  // AVisitor.Visit(self);
end;

{ TCommentStmt }

procedure TCommentStmt.Accept(const AVisitor: IVelocityVisitor);
begin
  // AVisitor.Visit(self);
end;

{ TAbstractBase }

constructor TAbstractBase.Create(const APosition: IPosition);
begin
  FPosition := APosition;
end;

destructor TAbstractBase.Destroy;
begin
  FPosition := nil;
  inherited;
end;

function TAbstractBase.GetPosition: IPosition;
begin
  result := FPosition;
end;

{ TMethodCallExpr }

procedure TMethodCallExpr.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

constructor TMethodCallExpr.Create(const APosition: IPosition; const AObjectExpr: IExpr; const AMethod: string; const AExprList: IExprList);
begin
  FPosition := APosition;
  FObjectExpr := AObjectExpr;
  FMethod := AMethod;
  FExprList := AExprList;
end;

function TMethodCallExpr.GetExprList: IExprList;
begin
  result := FExprList;
end;

function TMethodCallExpr.GetMethod: string;
begin
  result := FMethod;
end;

function TMethodCallExpr.GetObject: IExpr;
begin
  result := FObjectExpr;
end;

function TMethodCallExpr.GetRttiMethod: TRttiMethod;
begin
  result := FRttiMethod;
end;

procedure TMethodCallExpr.SetRttiMethod(const ARttiMethod: TRttiMethod);
begin
  FRttiMethod := ARttiMethod;
end;

{ TEncodeStmt }

procedure TEncodeExpr.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

constructor TEncodeExpr.Create(const APosition: IPosition; const AExpr: IExpr);
begin
  inherited Create(APosition);
  FExpr := AExpr;
end;

function TEncodeExpr.GetExpr: IExpr;
begin
  result := FExpr;
end;

{ TProcessTemplateStmt }

procedure TProcessTemplateStmt.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

constructor TProcessTemplateStmt.Create(const APosition: IPosition; const AContainer: IVelocityTemplate);
begin
  inherited Create(APosition);
  FContainer := AContainer;
end;

function TProcessTemplateStmt.GetContainer: IVelocityTemplate;
begin
  result := FContainer;
end;

{ TDefineTemplateStmt }

procedure TDefineTemplateStmt.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

constructor TDefineTemplateStmt.Create(const APosition: IPosition; const AName: IExpr; const AContainer: IVelocityTemplate);
begin
  inherited Create(APosition);
  FName := AName;
  FContainer := AContainer;
end;

function TDefineTemplateStmt.GetName: IExpr;
begin
  result := FName;
end;

function TDefineTemplateStmt.GetContainer: IVelocityTemplate;
begin
  result := FContainer;
end;

{ TWithStmt }

procedure TWithStmt.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

constructor TWithStmt.Create(const APosition: IPosition; const AExpr: IExpr; const AContainer: IVelocityTemplate);
begin
  inherited Create(APosition);
  FExpr := AExpr;
  FContainer := AContainer;
end;

function TWithStmt.GetContainer: IVelocityTemplate;
begin
  result := FContainer;
end;

function TWithStmt.GetExpr: IExpr;
begin
  result := FExpr;
end;

{ TIfExpr }

procedure TTernaryExpr.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

constructor TTernaryExpr.Create(const APosition: IPosition; const ACondition, ATrueExpr, AFalseExpr: IExpr);
begin
  inherited Create(APosition);
  FCondition := ACondition;
  FTrueExpr := ATrueExpr;
  FFalseExpr := AFalseExpr;
end;

function TTernaryExpr.GetCondition: IExpr;
begin
  result := FCondition;
end;

function TTernaryExpr.GetFalseExpr: IExpr;
begin
  result := FFalseExpr;
end;

function TTernaryExpr.GetTrueExpr: IExpr;
begin
  result := FTrueExpr;
end;

{ TArrayExpr }

procedure TArrayExpr.Accept(const AVisitor: IVelocityVisitor);
begin
  AVisitor.Visit(self);
end;

constructor TArrayExpr.Create(const APosition: IPosition; const AValue: IExprList);
begin
  inherited Create(APosition);
  FValue := AValue;
end;

function TArrayExpr.GetValue: IExprList;
begin
  result := FValue;
end;

procedure initOps;
var
  s: TVelocitySymbol;
  bo: TBinOp;
begin
  for s := Low(TVelocitySymbol) to High(TVelocitySymbol) do
    GVelocityBinOps[s] := boInvalid;
  for bo := Low(TBinOp) to High(TBinOp) do
    GBinopPrecedents[bo] := pInvalid;
  GVelocityBinOps[vsin] := boIN;
  GVelocityBinOps[VsAND] := boAND;
  GVelocityBinOps[vsOR] := boOR;
  GVelocityBinOps[VsPLUS] := boPlus;
  GVelocityBinOps[VsMinus] := boMinus;
  GVelocityBinOps[VsMULT] := boMult;
  GVelocityBinOps[VsDIV] := boDiv;
  GVelocityBinOps[VsMOD] := boMod;
  GVelocityBinOps[vsLT] := roLT;
  GVelocityBinOps[vsLTE] := roLTE;
  GVelocityBinOps[vsGT] := roGT;
  GVelocityBinOps[vsGTE] := roGTE;
  GVelocityBinOps[vsEQ] := roEQ;
  GVelocityBinOps[VsNotEQ] := roNotEQ;

  GBinopPrecedents[TBinOp.boOR] := 1;
  GBinopPrecedents[TBinOp.boAND] := 2;
  GBinopPrecedents[TBinOp.boIN] := 2;

  GBinopPrecedents[TBinOp.roEQ] := 5;
  GBinopPrecedents[TBinOp.roNotEQ] := 5;

  GBinopPrecedents[TBinOp.roLT] := 10;
  GBinopPrecedents[TBinOp.roLTE] := 10;
  GBinopPrecedents[TBinOp.roGT] := 10;
  GBinopPrecedents[TBinOp.roGTE] := 10;

  GBinopPrecedents[TBinOp.boPlus] := 15;
  GBinopPrecedents[TBinOp.boMinus] := 15;

  GBinopPrecedents[TBinOp.boMult] := 20;
  GBinopPrecedents[TBinOp.boDiv] := 20;
  GBinopPrecedents[TBinOp.boMod] := 20;

end;

initialization

initOps;

end.
