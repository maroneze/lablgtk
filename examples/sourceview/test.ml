(*********************************************************************************)
(*                                                                               *)
(*   lablgtksourceview, OCaml binding for the GtkSourceView text widget          *)
(*                                                                               *)
(*   Copyright (C) 2005  Stefano Zacchiroli <zack@cs.unibo.it>                   *)
(*   Copyright (C) 2006  Stefano Zacchiroli <zack@cs.unibo.it>                   *)
(*                       Maxence Guesdon <maxence.guesdon@inria.fr>              *)
(*                                                                               *)
(*   This library is free software; you can redistribute it and/or modify        *)
(*   it under the terms of the GNU Lesser General Public License as              *)
(*   published by the Free Software Foundation; either version 2.1 of the        *)
(*   License, or (at your option) any later version.                             *)
(*                                                                               *)
(*   This library is distributed in the hope that it will be useful, but         *)
(*   WITHOUT ANY WARRANTY; without even the implied warranty of                  *)
(*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU           *)
(*   Lesser General Public License for more details.                             *)
(*                                                                               *)
(*   You should have received a copy of the GNU Lesser General Public            *)
(*   License along with this library; if not, write to the Free Software         *)
(*   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307         *)
(*   USA                                                                         *)
(*                                                                               *)
(*********************************************************************************)

(* Compile with 
   ocamlc -o viewer -I ../../src/ lablgtk.cma lablgtksourceview.cma gtkInit.cmo test.ml
   Run with 
   CAML_LD_LIBRARY_PATH=../../src ./viewer
*)

open Printf

let lang_mime_type = "text/x-ocaml"
let lang_file = "ocaml.lang"
let use_mime_type = false
let font_name = "Monospace 10"

let print_lang lang = prerr_endline (sprintf "language: %s" lang#get_name)

let print_lang_dirs languages_manager =
  let i = ref 0 in
  prerr_endline "lang_dirs:";
  List.iter
    (fun dir -> incr i; prerr_endline (sprintf "%d: %s" !i dir))
    languages_manager#lang_files_dirs

let win = GWindow.window ~title:"LablGtkSourceView test" ()
let vbox = GPack.vbox ~packing:win#add ()
let hbox = GPack.hbox ~packing:(vbox#pack ~expand: false) ()
let bracket_button = GButton.button ~label:"( ... )" ~packing:hbox#add ()
let scrolled_win = GBin.scrolled_window
    ~hpolicy: `AUTOMATIC ~vpolicy: `AUTOMATIC
    ~packing:vbox#add ()
let source_view =
  GSourceview.source_view
    ~auto_indent:true
     ~insert_spaces_instead_of_tabs:true ~tabs_width:2
    ~show_line_numbers:true
    ~margin:80 ~show_margin:true
    ~smart_home_end:true
    ~packing:scrolled_win#add ~height:500 ~width:650
    ()
(* let languages_manager =
  GSourceView.source_languages_manager ~lang_files_dirs:["/etc"] () *)
let languages_manager = GSourceview.source_languages_manager ()

let lang =
  if use_mime_type then
    match languages_manager#get_language_from_mime_type lang_mime_type with
    | None -> failwith (sprintf "no language for %s" lang_mime_type)
    | Some lang -> lang
  else
    match
      GSourceview.source_language_from_file ~languages_manager lang_file
    with
    | None -> failwith (sprintf "can't load %s" lang_file)
    | Some lang -> lang

let matching_bracket () =
  let iter = source_view#source_buffer#get_iter_at_mark `INSERT in
  match GSourceview.find_matching_bracket iter with
  | None -> prerr_endline "no matching bracket"
  | Some iter ->
      source_view#source_buffer#place_cursor iter;
      source_view#misc#grab_focus ()

let _ =
  let text =
    let ic = open_in "test.ml" in
    let size = in_channel_length ic in
    let buf = String.create size in
    really_input ic buf 0 size;
    close_in ic;
    buf
  in
  win#set_allow_shrink true;
  source_view#misc#modify_font_by_name font_name;
  print_lang_dirs languages_manager;
  print_lang lang;

  (* set red as foreground color for definition keywords *)
  let id = "Definition@32@keyword" in
  let st = lang#get_tag_style id in
  st#set_foreground_by_name "red";
  lang#set_tag_style id st;

  (* set a style for bracket matching *)
  source_view#source_buffer#set_check_brackets true;
  let _ =
    let st = GSourceview.source_tag_style
	~background_by_name:"green"
	~foreground_by_name:"yellow"
	~bold: true
	()
    in
    source_view#source_buffer#set_bracket_match_style st
  in

  source_view#source_buffer#set_language lang;
  source_view#source_buffer#set_highlight true;
  source_view#source_buffer#set_text text;
  ignore (win#connect#destroy (fun _ -> GMain.quit ()));
  ignore (bracket_button#connect#clicked matching_bracket);
(*   ignore (source_view#connect#move_cursor (fun _ _ ~extend ->
    prerr_endline "move_cursor"));
  ignore (source_view#connect#undo (fun _ -> prerr_endline "undo")); *)
  win#show ();
  GMain.Main.main ()