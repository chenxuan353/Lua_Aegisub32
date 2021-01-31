--[[
 Copyright (c) 2005-2010, Niels Martin Hansen, Rodrigo Braz Monteiro
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

   * Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer.
   * Redistributions in binary form must reproduce the above copyright notice,
     this list of conditions and the following disclaimer in the documentation
     and/or other materials provided with the distribution.
   * Neither the name of the Aegisub Group nor the names of its contributors
     may be used to endorse or promote products derived from this software
     without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
]]

util = require 'aegisub.util'

Yutils = require("Yutils")

algorithm = {}
shape = {}
decode = {}

-- shorten Yutils function name
table.append = Yutils.table.append
table.tostring = Yutils.table.tostring
 
math.arc_curve = Yutils.math.arc_curve
math.bezier = Yutils.math.bezier
math.create_matrix = Yutils.math.create_matrix
math.degree = Yutils.math.degree
math.distance = Yutils.math.distance
math.ortho = Yutils.math.ortho
math.randomsteps = Yutils.math.randomsteps
math.round = Yutils.math.round
math.stretch = Yutils.math.stretch
math.trim = Yutils.math.trim

algorithm.frames = Yutils.algorithm.frames
algorithm.lines = Yutils.algorithm.lines

shape.bounding = Yutils.shape.bounding
shape.detect = Yutils.shape.detect
shape.filter = Yutils.shape.filter
shape.flatten = Yutils.shape.flatten
shape.glue = Yutils.shape.glue
shape.move = Yutils.shape.move
shape.split = Yutils.shape.split
shape.to_outline = Yutils.shape.to_outline
shape.to_pixels = Yutils.shape.to_pixels
shape.transform = Yutils.shape.transform

decode.create_bmp_reader = Yutils.decode.create_bmp_reader
decode.create_font = Yutils.decode.create_font
decode.list_fonts = Yutils.decode.list_fonts
-- end



table.copy = util.copy
copy_line = util.copy
table.copy_deep = util.deep_copy
ass_color = util.ass_color
ass_alpha = util.ass_alpha
ass_style_color = util.ass_style_color
extract_color = util.extract_color
alpha_from_style = util.alpha_from_style
color_from_style = util.color_from_style
HSV_to_RGB = util.HSV_to_RGB
HSL_to_RGB = util.HSL_to_RGB
clamp = util.clamp
interpolate = util.interpolate
interpolate_color = util.interpolate_color
interpolate_alpha = util.interpolate_alpha
string.headtail = util.headtail
string.trim = util.trim
string.words = util.words
