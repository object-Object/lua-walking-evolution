function round(num,dec)
    return math.floor((num*10^dec+0.5))/(10^dec)
end

print(round(102.192557,4))