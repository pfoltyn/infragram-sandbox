image = null

class Image
        constructor: (@data, @width, @height, @channels) ->

        copyToImageData: (imgData) ->
                imgData.data.set(@data)

        extrema: ->
                n = @width * @height
                mins = (@data[i] for i in [0...@channels])
                maxs = (@data[i] for i in [0...@channels])
                j = 0
                for i in [0...n]
                        for c in [0...@channels]
                                if @data[j] > maxs[c]
                                        maxs[c] = @data[j]
                                if @data[j] < mins[c]
                                        mins[c] = @data[j]
                                j++
                return [mins, maxs]
        
histogram = (array, [min,max], nbins) ->
        bins = (0 for i in [0...nbins])
        d = (max - min) / nbins
        for a in array
                i = Math.floor((a - min) / d)
                if 0 <= i < nbins
                        bins[i]++
        return bins

segmented_colormap = (segments) -> (x) ->
        [y0, y1] = [0, 0]
        [x0, x1] = [segments[0][0], 1]
        if x < x0
                return y0
        
        for [xstart, y0, y1],i in segments
                x0 = xstart
                if i == segments.length - 1
                        x1 = 1
                        break
                x1 = segments[i+1][0]
                if xstart <= x < x1
                        break

        result = []
        for i in [0...y0.length]:
                result[i] = (x-x0) / (x1 - x0) * (y1[i] - y0[i]) + y0[i]
        return result
                        
get_channels = (img) ->
        n = img.width * img.height;
        r = new Float32Array(n);
        g = new Float32Array(n);
        b = new Float32Array(n);
        for i in [0...n]
                r[i] = img.data[4*i + 0];
                g[i] = img.data[4*i + 1];
                b[i] = img.data[4*i + 2];
        mkImage = (d) -> new Image(d, img.width, img.height, 1);
        return [mkImage(r), mkImage(g), mkImage(b)];

nvdi = (nir, vis) ->
        n = nir.width * nir.height;
        d = new Float64Array(n);
        for i in [0...n]
                d[i] = (nir.data[i] - vis.data[i]) / (nir.data[i] + vis.data[i]);
        return new Image(d, nir.width, nir.height, 1);

colorify = (img, colormap) -> 
        n = img.width * img.height;
        data = new Uint8ClampedArray(4*n);
        j = 0;
        for i in [0...n]
                [r,g,b] = colormap(img.data[i]);
                data[j++] = r;
                data[j++] = g;
                data[j++] = b;
                data[j++] = 255;
        cimg = new Image();
        cimg.width = img.width;
        cimg.height = img.height;
        cimg.data = data;
        return new Image(data, img.width, img.height, 4);

render = (img) ->
        e = document.getElementById("image");
        e.width = img.width
        e.height = img.height
        ctx = e.getContext("2d");
        d = ctx.getImageData(0, 0, img.width, img.height);
        img.copyToImageData(d);
        ctx.putImageData(d, 0, 0);

update = (img) ->
        mode = $('input[name="output-type"]:checked').val()
        if mode == "nvdi"
            [r,g,b] = get_channels(img)
            nvdi_img = nvdi(r,b)
            [[min],[max]] = nvdi_img.extrema()
            d = max - min
            colormap = (x) ->
                y = 255/d * (x - min)
                return [y, y, y]
            result = colorify(nvdi_img, colormap)
        else if mode == "raw"
            result = img
        else if mode == "nir"
            [r,g,b] = get_channels(img)
            result = colorify(r, (x) -> [x, x, x])
        render(result)
        
file_reader = new FileReader();
file_reader.onload = (oFREvent) ->
        file = document.forms["file-form"]["file-sel"].files[0];
        data = new Uint8Array(file_reader.result);
        if file.type == "image/png"
            png = new PNG(data);
            data = png.decode()
            img = new Image(data, png.width, png.height);
        else if file.type == "image/jpeg"
            jpeg = new JpegImage();
            jpeg.parse(data);
            d = new Uint8ClampedArray(4 * jpeg.width * jpeg.height);
            img = new Image(d, jpeg.width, jpeg.height, 4);
            jpeg.copyToImageData(img);
        else
            document.getElementById("error").html = "Unrecognized file format (supports PNG and JPEG)";
            return

        image = img
        update(img)

on_file_sel = () ->
        file = document.forms["file-form"]["file-sel"].files[0];
        if file
                file_reader.readAsArrayBuffer(file);
