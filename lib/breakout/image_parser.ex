defmodule Breakout.ImageParser do
  require Logger
  def parse(data) do
    res = do_parse(data, %{})
    {:ok, res}
  end

  defp do_parse(<<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, rest::binary>>, acc) do
    do_png_parse(rest, acc)
    |> decompress_png()
    |> reconstruct_png()
  end

  defp do_parse(<<0xFF, 0xD8, 0xFF, rest::binary>>, acc) do
    do_jpg_parse(rest, acc)
  end

  def do_jpg_parse(_rest, _acc) do
  end

  defp decompress_png(%{IDAT: data} = map) do
    Map.put(map, :IDAT, :zlib.uncompress(data))
  end

  defp paeth_predictor(a, b, c) do
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)

    cond do
      pa <= pb and pa <= pc -> a
      pb <= pc -> b
      true -> c
    end
  end

  defp recon_a(recon, _width, _height, _stride, bytes_per_pixel, i, c) do
    if c >= bytes_per_pixel do
      :binary.at(recon, i - bytes_per_pixel)
    else
      0
    end
  end

  defp recon_b(recon, _width, _height, stride, _bytes_per_pixel, i, _c) do
    if i >= stride do
      :binary.at(recon, i - stride)
    else
      0
    end
  end

  defp recon_c(recon, _width, _height, stride, bytes_per_pixel, i, c) do
    if i >= stride and c >= bytes_per_pixel do
      :binary.at(recon, i - stride - bytes_per_pixel)
    else
      0
    end
  end

  defp reconstruct_png(%{IDAT: data, IHDR: %{width: width, height: height, type: type, depth: depth}} = map) do
    if width == 256 and height == 96, do: dbg(map)
    bytes_per_pixel = case type do
      0 -> depth / 8
      2 -> 3 * depth / 8
      3 -> depth / 8
      4 -> 4 * depth / 8
      6 -> 4 * depth / 8
      _ -> raise "unknown type #{type}"
    end
    |> trunc()

    stride = width * bytes_per_pixel

    res = reconstruct_rows(data, width, height, stride, bytes_per_pixel, <<>>, 0)
    Map.put(map, :IDAT, res)
  end

  defp reconstruct_rows(<<>>, _width, _height, _stride, _bytes_per_pixel, recon, _i), do: recon

  defp reconstruct_rows(
         <<filter_type, rest::binary>>,
         width,
         height,
         stride,
         bytes_per_pixel,
         recon,
         i
       ) do
    {recon, rest, i} =
      0..(stride - 1)
      |> Enum.reduce({recon, rest, i}, fn c, {recon_acc, rest_acc, i_acc} ->
        <<filt_x, rest_acc::binary>> = rest_acc

        recon_x =
          case filter_type do
            0 ->
              filt_x

            1 ->
              filt_x + recon_a(recon_acc, width, height, stride, bytes_per_pixel, i_acc, c)

            2 ->
              filt_x + recon_b(recon_acc, width, height, stride, bytes_per_pixel, i_acc, c)

            3 ->
              filt_x +
                div(
                  recon_a(recon_acc, width, height, stride, bytes_per_pixel, i_acc, c) +
                    recon_b(recon_acc, width, height, stride, bytes_per_pixel, i_acc, c),
                  2
                )

            4 ->
              filt_x +
                paeth_predictor(
                  recon_a(recon_acc, width, height, stride, bytes_per_pixel, i_acc, c),
                  recon_b(recon_acc, width, height, stride, bytes_per_pixel, i_acc, c),
                  recon_c(recon_acc, width, height, stride, bytes_per_pixel, i_acc, c)
                )

            _ ->
              raise "unknown filter type: #{filter_type}"
          end

        {<<recon_acc::binary, (<<rem(recon_x, 256)>>)>>, rest_acc, i_acc + 1}
      end)

    reconstruct_rows(rest, width, height, stride, bytes_per_pixel, recon, i)
  end

  defp do_png_parse(<<len::8*4, type::8*4, data::unit(8)-size(len), crc::8*4, rest::binary>>, acc) do
    my_crc = :erlang.crc32(<<type::32, data::unit(8)-size(len)>>)

    unless my_crc == crc do
      raise "Invalid crc"
    end

    acc =
      case do_png_chunk(<<type::32>>, <<data::unit(8)-size(len)>>) do
        {:IDAT, data} -> Map.put(acc, :IDAT, Map.get(acc, :IDAT, <<>>) <> data)
        {key, vals} -> Map.put(acc, key, vals)
        _ -> acc
      end

    do_png_parse(rest, acc)
  end

  defp do_png_parse(<<>>, acc), do: acc

  defp do_png_chunk(
         "IHDR",
         <<width::8*4, height::8*4, depth::8, type::8, compression::8, filter::8, interlace::8>> =
           _data
       ) do
    {:IHDR,
     %{
       width: width,
       height: height,
       depth: depth,
       type: type,
       compression: compression,
       filter: filter,
       interlace: interlace
     }}
  end

  defp do_png_chunk("IDAT", data) do
    {:IDAT, data}
  end

  defp do_png_chunk("IEND", _) do
    :ok
  end

  defp do_png_chunk("sRGB", <<intent::8>>) do
    {:sRGB, %{intent: intent}}
  end

  defp do_png_chunk("pHYs", <<x::8*4, y::8*4, unit::8>>) do
    {:pHYs, %{x: x, y: y, unit: unit}}
  end

  defp do_png_chunk("tIME", <<year::8*2, month::8, day::8, hour::8, minute::8, second::8>>) do
    {:tIME, %{time: NaiveDateTime.new(year, month, day, hour, minute, second)}}
  end

  defp do_png_chunk("tEXt", data) do
    [keyword, data] = :binary.split(data, <<0>>)
    {:tEXt, %{keyword: keyword, data: data}}
  end

  defp do_png_chunk("iTXt", data) do
    [keyword, data] = :binary.split(data, <<0>>)
    <<compression_flag::8, compression_method::8, data::binary>> = data

    [lang_tag, data] = :binary.split(data, <<0>>)
    [translated_keyword, data] = :binary.split(data, <<0>>)

    xml = :xmerl_scan.string(:binary.bin_to_list(data))

    {:iTXt,
     %{
       keyword: keyword,
       data: xml,
       compression_flag: compression_flag,
       compression_method: compression_method,
       lang_tag: lang_tag,
       translated_keyword: translated_keyword
     }}
  end

  defp do_png_chunk("eXIf", data) do
    {:eXIf, data}
  end

  defp do_png_chunk("iCCP", data) do
    [profile_name, data] = :binary.split(data, <<0>>)

    <<compression_method::8, compressed_profile::bitstring>> = data

    uncompressed = :zlib.uncompress(compressed_profile)

    File.write("uncompressed", uncompressed)
    <<header::binary-size(128), tag_table::bitstring>> = uncompressed

    <<
      profile_size::unsigned-size(4)-unit(8), # 0-3
      preferred_cmm_type::binary-size(4), # 4-7
      # profile_version_raw::binary-size(2), # 8-11
      0::size(4),
      profile_version_major::size(4),
      profile_version_minor::size(4),
      0::size(4),
      0::unit(8)-size(2), # Lowest two are reserved
      profile_class::binary-size(4), # 12-15
      color_space::binary-size(4), # 16-20
      pcs::binary-size(4), # 20-23
      creation_date_time::binary-size(12), # 24-35
      "acsp", # 36-39
      primary_platform_signature::binary-size(4), # 40-43
      # profile_flags::binary-size(4), # 44-47
      flag_embedded::size(1),
      flag_independent::size(1),
      0::size(30),
      device_manufacturer::binary-size(4), # 48-51
      device_model::binary-size(4), # 52-55
      # device_attributes::binary-size(8), # 56-63 (really, 56-59)
      # TODO: these should probably be something like
      # attributes: %{reflective: true, glossy: false, ...}
      # or something. kind of awkward since they're mutually exclusive.
      reflective_or_transparency::size(1),
      glossy_or_matte::size(1),
      positive_or_negative_polarity::size(1),
      color_or_bw::size(1),
      0::size(28),
      device_attributes::binary-size(4), # really, 60-63
      rendering_intent::binary-size(4), # 64-67
      nciexyz::binary-size(12), # 68-79
      signature::binary-size(4), # 80-83
      profile_id::binary-size(16), # 84-99
      0::unit(8)-size(28) # 100-127
    >> = header

    profile_version = "#{profile_version_major}.#{profile_version_minor}"

    iccp = %{
        profile_name: profile_name,
        compression_method: compression_method,
        compressed_profile: compressed_profile,
        uncompressed: uncompressed,
        profile_size: profile_size,
        preferred_cmm_type: preferred_cmm_type,
        profile_version_major: profile_version_major,
        profile_version_minor: profile_version_minor,
        profile_version: profile_version,
        profile_class_raw: profile_class,
        profile_class: case profile_class do
          "mntr" -> :monitor
          "scnr" -> :scanner
          "prtr" -> :printer
          "link" -> :link
          "abst" -> :abstract
          "spac" -> :space
          "nmcl" -> :named_color
          _ -> :unknown
        end,
        color_space_raw: color_space,
        color_space: case color_space do
          "XYZ " -> [:nciexyz, :pcsxyz]
          "Lab " -> [:cielab, :pcslab]
          "Luv " -> :cieluv
          "YCbr" -> :ycbcr
          "Yxy " -> :cieyxy
          "RGB " -> :rgb
          "GRAY" -> :gray
          "HSV " -> :hsv
          "HLS " -> :hls
          "CMYK" -> :cmyk
          "CMY " -> :cmy
          # 2-15 color
          <<digit, "CLR">> when digit in ?0..?9//1 ->
            String.to_atom("color_#{[digit]}")
          <<digit, "CLR">> when digit in ?A..?F//1 ->
            String.to_atom("color_#{digit - ?A + 10}")
        end,
        pcs_raw: pcs,
        # TODO: kind of awkward to duplicate this.
        pcs: case color_space do
          # oh, this is where I decide (n)cie/pcs, I think?
          "XYZ " -> [:nciexyz, :pcsxyz]
          "Lab " -> [:cielab, :pcslab]
          _ -> :unknown
        end,
        creation_date_time_raw: creation_date_time,
        creation_date_time: parse_iccp_date_time(creation_date_time),
        primary_platform_signature_raw: primary_platform_signature,
        primary_platform_signature: case primary_platform_signature do
          "MSFT" -> :microsoft
          "APPL" -> :apple
          "ADBE" -> :adobe # this isn't specified in icc.1:2022, but is in some random other icc profile parser (icc node package)
          "SUNW" -> :sun_microsystems
          "SGI " -> :silicon_graphics
          "TGNT" -> :taligent # this isn't specified in icc.1:2022, but is in some random other icc profile parser (icc node package)
          _ -> :unknown
        end,
        profile_flags: %{
          embedded: flag_embedded,
          independent: flag_independent,
        },
        device_manufacturer: device_manufacturer,
        device_model: device_model,
        device_attributes: device_attributes,
        reflective_or_transparency: reflective_or_transparency,
        glossy_or_matte: glossy_or_matte,
        positive_or_negative_polarity: positive_or_negative_polarity,
        color_or_bw: color_or_bw,
        rendering_intent: rendering_intent,
        nciexyz: nciexyz,
        signature: signature,
        profile_id: profile_id,
      # TODO: This is just a list of pointers to the rest of the data
      tag_table: parse_tag_table(tag_table),
    }

    {:iCCP, iccp}
  end

  defp do_png_chunk("cHRM", data) do
    <<
      white_x::32,
      white_y::32,
      red_x::32,
      red_y::32,
      green_x::32,
      green_y::32,
      blue_x::32,
      blue_y::32
    >> = data

    chrm = %{
      white_x: white_x / 100_000,
      white_y: white_y / 100_000,
      red_x: red_x / 100_000,
      red_y: red_y / 100_000,
      green_x: green_x / 100_000,
      green_y: green_y / 100_000,
      blue_x: blue_x / 100_000,
      blue_y: blue_y / 100_000,
    }

    {:cHRM, chrm}
  end

  defp do_png_chunk(type, data) do
    IO.puts("unknown type #{type}")
    {String.to_atom(type), %{data: data}}
  end

  defp parse_iccp_date_time(<<year::16, month::16, day::16, hours::16, minutes::16, seconds::16>>) do
    DateTime.new(Date.new!(year, month, day), Time.new!(hours, minutes, seconds))
  end

  defp parse_tag_table(tag_table) do
    File.write("tag_table_raw", tag_table)
    # <<count::32, tag_table::binary-unit(8)-size(12*count), tagged_data::bitstring>> = tag_table
    <<count::32, tag_table::bitstring>> = tag_table

    table = do_parse_tag_table(tag_table, [], count)

    File.write("tag_table", tag_table)

    <<_tag_table::binary-size(count * 12), data::binary>> = tag_table

    File.write("data", data)

    first_offset = table |> hd() |> elem(1)
    table = Enum.map(table, fn {sig, offset, size} ->
      {sig, offset - first_offset, size}
    end)

    tagged_data = do_parse_tagged_data(table, data, %{})

    {table, tagged_data}

    # Enum.reduce(tag_table, fn <<signature::32, offset::32, size::32, _rest::>> = el, acc ->
    #   IO.inspect({signature, offset, size}, label: "tag")
    #   [el | acc]
    # end)
  end

  defp do_parse_tagged_data([], _data, acc) do
    acc
  end

  defp do_parse_tagged_data(_table, <<>>, acc) do
    # this is happening for every image it seems, so just mute the warning for now
    # Logger.warning("tag table indicates there's more data, but no more data exists in the tagged element data", msg: table)
    acc
  end

  defp do_parse_tagged_data(table, <<0::8, data::binary>>, acc) do
    do_parse_tagged_data(table, data, acc)
  end

  defp do_parse_tagged_data([{sig, _offset, size} | rest], data, acc) do
    <<to_parse::binary-size(size), next::binary>> = data
    parsed = do_parse_signature(to_parse)
    acc = put_in(acc[sig], parsed)
    do_parse_tagged_data(rest, next, acc)
  end

  defp do_parse_signature(<<"text", 0::32, text::binary>>) do
    text
    |> :binary.part(0, byte_size(text) - 1)
  end

  defp do_parse_signature(<<"desc", 0::32, rest::binary>>) do
    # from what I can tell.. this is like..
    # 0::32, length::32, data::size(length),
    # then.. 0::8, 0::8, length::32, repeat?
    # <<length::32, rest::binary>> = rest
    do_parse_desc(rest, [])
  end

  defp do_parse_signature(<<"XYZ ", 0::32, x_sign::16, x::signed-16, y_sign::16, y::16, z_sign::16, z::16>>) do
    # TODO: this is wrong, but the spec is pretty unclear about how this is supposed to work.
    {x_sign + x, y_sign + y, z_sign + z}
  end

  defp do_parse_signature(<<"view", 0::32, illuminant::binary-size(12), surround::binary-size(12), type::binary>>) do
    {illuminant, surround, type}
  end

  defp do_parse_signature(<<"meas", 0::32, observer::32, tristimulus::binary-size(12), geo::32, flare::32, illuminant::32>>) do
    {observer, tristimulus, geo, flare, illuminant}
  end

  defp do_parse_signature(<<"sig ", 0::32, sig::binary>>) do
    sig
  end

  defp do_parse_signature(<<"curv", 0::32, count::32, curves::binary>>) do
    {count, curves}
  end

  defp do_parse_signature(<<data::binary-size(4), rest::binary>>) do
    Logger.warning("unknown signature #{data}")

    # continue parsing, why not
    rest
  end

  defp do_parse_desc(<<>>, acc), do: Enum.reverse(acc)

  defp do_parse_desc(<<0::32, rest::binary>>, acc) do
    # TODO: this is hacky. I'm not sure why it ends with a single null byte.
    if byte_size(rest) < 4 do
      do_parse_desc(<<>>, acc)
    else
    do_parse_desc(rest, acc)
    end
  end

  defp do_parse_desc(data, acc) do
    <<length::32, next::binary>> = data

    <<res::binary-size(length - 1), next::binary>> = next
    do_parse_desc(next, [res | acc])
  end

  defp do_parse_tag_table(_data, acc, 0), do: Enum.reverse(acc)
  defp do_parse_tag_table(<<>>, _acc, _count), do: raise "premature end of data"

  defp do_parse_tag_table(<<signature::binary-size(4), offset::32, size::32, next::binary>>, acc, count) do
    do_parse_tag_table(next, [{signature, offset, size} | acc], count - 1)
  end
end
defmodule BCD do
  def decode(val) do
    Integer.undigits(for <<x::4 <- val>>, do: x)
  end
end
