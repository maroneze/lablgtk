(* $Id$ *)

open Xml_lexer

let parse_header lexbuf =
  begin match token lexbuf with Tag ("?xml",_,true) -> ()
  | _ -> failwith "no XML header" end;
  begin match token lexbuf with Tag ("gtk-interface",_,_) -> ()
  | Tag(tag,_,_) -> prerr_endline tag
  | _ -> failwith "no GTK-interface declaration" end

let parse_field lexbuf ~tag =
  let b = Buffer.create 80 and first = ref true in
  while match token lexbuf with
    Chars s ->
      if not !first then Buffer.add_char b '\n' else first := false;
      Buffer.add_string b s;
      true
  | Endtag tag' when tag = tag' ->
      false
  | _ ->
      failwith "bad field"
  do () done;
  Buffer.contents b

type wtree = {
    wclass: string;
    wname: string;
    wchildren: wtree list;
    mutable wrapped: bool;
  }

let rec parse_widget lexbuf =
  let wclass = ref None and wname = ref None and widgets = ref [] in
  while match token lexbuf with
    Tag ("class",_,false) ->
      wclass := Some (parse_field lexbuf ~tag:"class"); true
  | Tag ("name",_,false) ->
      wname := Some (parse_field lexbuf ~tag:"name"); true
  | Tag ("widget",_,false) ->
      widgets := parse_widget lexbuf :: !widgets; true
  | Tag (tag,_,closed) ->
      if not closed then while token lexbuf <> Endtag tag do () done; true
  | Endtag "widget" ->
      false
  | Chars _ ->
      true
  | Endtag _ | EOF ->
      failwith "bad XML syntax"
  do () done;
  match !wclass, !wname with
  | Some wclass, Some wname ->
      { wclass = wclass; wname = wname;
        wchildren = List.rev !widgets; wrapped = false }
  | Some wclass, None ->
      failwith ("no name for widget of class " ^ wclass)
  | None, Some wname ->
      failwith ("no class for widget " ^ wname)
  | None, None ->
      failwith "empty widget"

let classes = ref [
  "GtkWidget", ("GtkBase.Widget", "GObj.widget");
  "GtkContainer", ("GtkBase.Container", "GContainer.container");
  "GtkWindow", ("GtkWindow.Window", "GWindow.window");
  "GtkBox", ("GtkPack.Box", "GPack.box");
  "GtkHBox", ("GtkPack.Box", "GPack.box");
  "GtkVBox", ("GtkPack.Box", "GPack.box");
  "GtkMenu", ("GtkMenu.Menu", "GMenu.menu");
  "GtkMenuBar", ("GtkMenu.MenuBar", "GMenu.menu_shell");
  "GtkMenuItem", ("GtkMenu.MenuItem", "GMenu.menu_item");
  "GtkScrolledWindow", ("GtkBin.ScrolledWindow", "GBin.scrolled_window");
  "GtkText", ("GtkEdit.Text", "GEdit.text");
] 

let rec flatten_tree w =
  let children = List.map ~f:flatten_tree w.wchildren in
  w :: List.flatten children

let output_widget w =
  try
    let (modul, clas) = List.assoc w.wclass !classes in
    w.wrapped <- true;
    Printf.printf "    method %s = new %s\n" w.wname clas;
    Printf.printf "      (%s.cast (Glade.get_widget xml ~name:\"%s\"))\n"
      modul w.wname;
  with Not_found -> ()

let parse_body lexbuf =
  while match token lexbuf with
    Tag("project", _, closed) ->
      if not closed then while token lexbuf <> Endtag "project" do () done;
      true
  | Tag("widget", _, false) ->
      let wtree = parse_widget lexbuf in
      Printf.printf
	"class %s ~file =\n\
      \032 let () = Glade.init () in\n\
      \032 let xml = Glade.create ~file ~root:\"%s\" in\n\
      \032 object (self)\n\
      \032   method xml = xml\n\
      \032   method extra_handlers = []\n\
      \032   initializer Glade.bind_handlers ~extra:self#extra_handlers xml\n"
	  wtree.wname wtree.wname;
      let widgets = flatten_tree wtree in
      List.iter widgets ~f:output_widget;
      Printf.printf "    method check_widgets () =\n";
      List.iter widgets ~f:
	(fun w ->
	  if w.wrapped then Printf.printf "      ignore self#%s;\n" w.wname);
      Printf.printf "  end\n";
      true
  | Tag(tag, _, closed) ->
      if not closed then while token lexbuf <> Endtag tag do () done; true
  | Chars _ -> true
  | Endtag "gtk-interface" -> false
  | Endtag _ ->
      failwith "bad XML syntax"
  | EOF -> false
  do () done

let process ~name chan =
  let lexbuf = Lexing.from_channel chan in
  try
    parse_header lexbuf;
    Printf.printf "(* Automatically generated from %s by lablgladecc *)\n\n"
      name;
    parse_body lexbuf
  with Failure s ->
    Printf.eprintf "lablgladecc: in %s, before char %d, %s\n"
      name (Lexing.lexeme_start lexbuf) s

let main () =
  if Array.length Sys.argv = 1 then
    process ~name:"standard input" stdin
  else if List.mem Sys.argv.(1) ["-h"; "-help"; "--help"] then
    begin
      prerr_string "%s <file.glade> \n";
      prerr_string
        "  Convert glade specification file to caml wrappers, to be used\n";
      prerr_string "  with libglade. Results are on standard output.\n"
    end
  else
    for i = 1 to Array.length Sys.argv - 1 do
      let chan = open_in Sys.argv.(i) in
      process ~name:Sys.argv.(i) chan;
      close_in chan
    done  

let () =
  Printexc.print main ()
