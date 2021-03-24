open HexUtil

type color_char = {
  color : ANSITerminal.color;
  chara : char;
}

type color_char_grid = color_char option list list

type raster = {
  grid : color_char_grid;
  width : int;
  height : int;
}

type t = {
  width : int;
  height : int;
  layers : (string * raster) list;
  layer_order : string list;
  graphics : (string * raster) list;
}

let map_offset f big_lst small_lst offset =
  assert (offset >= 0);
  let rec map_offset_helper f big_lst small_lst offset acc =
    match small_lst with
    | [] -> List.rev acc @ big_lst
    | sl_h :: sl_t -> (
        match offset with
        | 0 -> (
            match big_lst with
            | [] ->
                failwith
                  "offset + length small_lst exceeds length big_lst"
            | bl_h :: bl_t ->
                map_offset_helper f bl_t sl_t 0 (f bl_h sl_h :: acc) )
        | o -> (
            (* print_int o; print_newline (); *)
            match big_lst with
            | [] -> failwith "offset exceeds length big_lst"
            | bl_h :: bl_t ->
                map_offset_helper f bl_t small_lst (o - 1) (bl_h :: acc)
            ) )
  in
  map_offset_helper f big_lst small_lst offset []

let draw gui graphic_name x y layer =
  let graphic = List.assoc graphic_name gui.graphics in
  let row_draw grid_r graphic_r =
    map_offset
      (fun grid_char graphic_char ->
        match graphic_char with None -> grid_char | c -> c)
      grid_r graphic_r x
  in
  { graphic with grid = map_offset row_draw layer.grid graphic.grid y }

let update_layer layer_name f gui =
  let new_layer = f (List.assoc layer_name gui.layers) in
  {
    gui with
    layers =
      (layer_name, new_layer) :: List.remove_assoc layer_name gui.layers;
  }

let update_cells gui cells =
  gui
  |> update_layer "hexes" (draw gui "hex" 0 0)
  |> update_layer "hexes2" (draw gui "hex" 1 1)
  |> update_layer "hexes" (draw gui "empty" 10 5)
  |> update_layer "hexes2" (draw gui "horiz" 90 29)
  |> update_layer "hexes" (draw gui "vert" 99 0)
  |> update_layer "hexes" (draw gui "hex" 91 25)
  |> update_layer "background" (draw gui "hex" 50 5)

let update_sun gui dir = gui

let fill_raster c w h =
  let rec fill_grid c w h =
    let rec fill_row c w =
      match w with 0 -> [] | n -> c :: fill_row c (w - 1)
    in
    match h with 0 -> [] | n -> fill_row c w :: fill_grid c w (h - 1)
  in
  { grid = fill_grid c w h; width = w; height = h }

(** [blank_raster w h] is a raster with a rectangular grid of [None]
    char options with width [w] and height [h]. *)
let blank_raster w h = fill_raster None w h

(** [null_raster] is a raster with an empty grid and 0 width and height. *)
let null_raster = blank_raster 0 0

(** [load_graphics none_c names] is an associative list mapping the
    [string] graphic names in [names] to the corresponding graphics,
    where each graphic is in the form of a [grid]. Each line
    ([char option list]) in the [grid] will contain elements up to, but
    not including the next ['\n']. The character [none_c] will be
    represented as [None], while all other characters [c] will be
    represented as [Some c]. It is possible that for the graphics to be
    represented by non-rectangular lists. *)

let load_char_grid none_c filename =
  let rec load_char_grid_helper ic g_acc =
    (* [load_line ic l_acc] is None when [ic] is at EOF. Otherwise, it
       is [Some line], where [line] is a char option list. [line] will
       contain char options up to, but not including the next ['\n'].
       The character [' '] will be represented as [None], while all
       other characters [c] will be represented as [Some c]. *)
    let rec load_line ic l_acc =
      try
        match input_char ic with
        | '\n' -> (
            match l_acc with
            | None -> Some []
            | Some a -> Some (List.rev a) )
        | c ->
            let c_opt = if c = none_c then None else Some c in
            load_line ic
              ( match l_acc with
              | None -> Some [ c_opt ]
              | Some a -> Some (c_opt :: a) )
      with End_of_file -> (
        match l_acc with None -> None | Some a -> Some (List.rev a) )
    in
    match load_line ic None with
    | None -> List.rev g_acc
    | Some line -> load_char_grid_helper ic (line :: g_acc)
  in
  let input_channel = open_in filename in
  let result = load_char_grid_helper input_channel [] in
  close_in input_channel;
  result

(** [raster_of_grid grid] is a raster with [grid = grid],
    [height = List.length grid] and [width] equal to the length of the
    longest list in [grid]. *)
let raster_of_grid grid =
  let h = List.length grid in
  let w =
    List.fold_left
      (fun curr_len x ->
        let x_len = List.length x in
        if x_len > curr_len then x_len else curr_len)
      0 grid
  in
  { grid; height = h; width = w }

(** [map2_grid f grid1 grid2] is a list of lists [result] with the
    dimensions of [grid1] and [grid2], where
    [result.(i).(j) = f grid1.(i).(j) grid2.(i).(j)]. Requires: the
    dimensions of grid1 are the same as the dimensions of grid2. *)
let map2_grid f grid1 grid2 =
  List.map2 (fun row1 row2 -> List.map2 f row1 row2) grid1 grid2

(** [map_grid f grid] is a list of lists [result] with the dimensions of
    [grid1], where [result.(i).(j) = f grid1.(i).(j)]. *)
let map_grid f grid = List.map (fun row -> List.map f row) grid

let combine_to_color_char_grid char_grid color_grid =
  let combine_to_color_char chara_opt color_opt =
    match (chara_opt, color_opt) with
    | None, None -> None
    | None, Some _ -> None
    | Some _, None -> None
    | Some chara, Some color -> Some { chara; color }
  in
  map2_grid combine_to_color_char char_grid color_grid

let txt_opt_to_color_opt c_opt =
  match c_opt with
  | None -> None
  | Some c ->
      Some
        ANSITerminal.(
          match c with
          | 'r' -> Red
          | 'g' -> Green
          | 'y' -> Yellow
          | 'b' -> Blue
          | 'm' -> Magenta
          | 'c' -> Cyan
          | 'w' -> White
          | 'd' -> Default
          | other ->
              failwith ("invalid color code " ^ String.make 1 other))

let load_graphics none_c names =
  let load_graphic name =
    let txt_grid =
      load_char_grid none_c ("graphics/" ^ name ^ ".txt")
    in
    let color_grid =
      load_char_grid none_c ("graphics/" ^ name ^ ".color")
    in
    combine_to_color_char_grid txt_grid
      (map_grid txt_opt_to_color_opt color_grid)
    |> raster_of_grid
  in
  List.map (fun n -> (n, load_graphic n)) names

let xy_of_hex_coord coord = (coord.diag, coord.col)

(** [draw_hex gui cell] returns [gui] with a hex drawn in its "hexes"
    layer with the position corresponding to the coords of [cell]. *)
let draw_hex gui cell =
  let x, y = xy_of_hex_coord cell in
  update_layer "hexes" (draw gui "hex" x y) gui

(** [draw_hexes gui cells] returns [gui] with hexes drawn in its "hexes"
    layer with the positions corresponding to the coords of each cell in
    [cells]. *)
let draw_hexes gui cells = List.fold_left draw_hex gui cells

(** [init_gui cells] is a GUI with the layers of rasters necessary to
    run the game. Postcondition: Each raster in
    [(init_gui cells).layers] has the same dimensions. *)
let init_gui cells =
  let w = 100 in
  let h = 30 in
  let gui =
    {
      width = w;
      height = h;
      layers =
        [
          ( "background",
            fill_raster
              (Some { chara = '.'; color = ANSITerminal.Magenta })
              w h );
          ("hexes", blank_raster w h);
          ("hexes2", blank_raster w h);
        ];
      layer_order = [ "background"; "hexes"; "hexes2" ];
      graphics =
        load_graphics ' ' [ "hex"; "dot"; "empty"; "vert"; "horiz" ];
    }
  in
  update_cells (draw_hexes gui cells) cells

(** (Deprecated) [past_n lst n] is the list containing the contents of
    [lst] including and after index [n]. Returns [\[\]] if
    [n = length lst]. Requires [0 <= n <= length lst]. *)
let past_n n lst =
  assert (n >= 0);
  match n with
  | 0 -> lst
  | n -> (
      match lst with
      | [] -> failwith "n exceeds length of lst"
      | h :: t -> t )

let merge_two_layers under over =
  let new_grid =
    map2_grid
      (fun u o -> match o with None -> u | o -> o)
      under.grid over.grid
  in
  { under with grid = new_grid }

let merge_layers layer_order layers =
  let rec merge_layers_helper layer_order layers acc =
    match layer_order with
    | [] -> acc
    | h :: t ->
        merge_layers_helper t layers
          (merge_two_layers acc (List.assoc h layers))
  in
  match layer_order with
  | [] -> null_raster
  | [ h ] -> List.assoc h layers
  | h :: t -> merge_layers_helper t layers (List.assoc h layers)

let render gui =
  let print_grid g =
    let print_row row =
      List.iter
        (fun c_char_opt ->
          match c_char_opt with
          | None -> print_char ' '
          | Some c_char ->
              ANSITerminal.print_string
                [ Foreground c_char.color ]
                (String.make 1 c_char.chara))
        row
    in
    List.iter
      (fun row ->
        print_row row;
        print_newline ())
      g
  in
  let render_raster = merge_layers gui.layer_order gui.layers in
  print_grid render_raster.grid
