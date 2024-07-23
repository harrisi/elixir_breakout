defmodule Breakout.ImageParser do
  def parse(data) do
    IO.inspect("about to parse in parse")
    res = do_parse(data, %{})
    {:ok, res}
  end

  defp do_parse(<<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, rest::binary>>, acc) do
    IO.inspect("in png header")

    do_png_parse(rest, acc)
    |> decompress_png()
    |> reconstruct_png()
  end

  defp do_parse(<<0xFF, 0xD8, 0xFF, rest::binary>>, acc) do
    do_jpg_parse(rest, acc)
  end

  def do_jpg_parse(rest, acc) do
    IO.inspect("in jpg")
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

  defp reconstruct_png(%{IDAT: data, IHDR: %{width: width, height: height, type: type}} = map) do
    # TODO: this is wrong, but the rgb/rgba issue was causing problems.
    bytes_per_pixel = if type == 6, do: 4, else: 3
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
      IO.inspect("invalid crc")
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
           data
       ) do
    IO.inspect({width, height, depth, type, compression, filter, interlace})

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

  defp do_png_chunk("IDAT", data) do
    {:IDAT, data}
  end

  defp do_png_chunk("IEND", _) do
    :ok
  end

  defp do_png_chunk("eXIf", data) do
    {:eXIf, data}
  end

  defp do_png_chunk(type, data) do
    IO.puts("unknown type #{type}")
    {String.to_atom(type), %{data: data}}
  end
end
