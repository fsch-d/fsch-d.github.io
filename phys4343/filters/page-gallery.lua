function Image(img)
  if not img.classes:includes("nolightbox") then
    if not img.attributes["group"] then
      img.attributes["group"] = "page-gallery"
    end
  end
  return img
end
