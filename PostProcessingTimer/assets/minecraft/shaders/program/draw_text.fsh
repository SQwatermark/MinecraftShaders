#version 150

uniform sampler2D TimeSampler;
uniform sampler2D FontSampler;  // ASCII 32x8 characters font texture unit

uniform sampler2D DiffuseSampler;

uniform float Time;

in vec2 texCoord;
out vec4 fragColor;

float iTime;

//==========================================================================================
// 调试信息，代码取自 https://docs.google.com/document/d/15TOAOVLgSNEoHGzpNlkez5cryH3hFF3awXL5Py81EMk/
//==========================================================================================

const float FXS = 0.02;         // font/screen resolution ratio
const float FYS = 0.02;         // font/screen resolution ratio
const int TEXT_BUFFER_LENGTH = 32;
int text[TEXT_BUFFER_LENGTH];
int textIndex;

void floatToDigits(float x) {
    float y, a;
    const float base = 10.0;

    // Handle sign
    if (x < 0.0) { 
		text[textIndex] = '-'; textIndex++; x = -x; 
	} else { 
		//text[textIndex] = '+'; textIndex++; 
	}

    // Get integer (x) and fractional (y) part of number
    y = x; 
    x = floor(x); 
    y -= x;

    // Handle integer part
    int i = textIndex;  // Start of integer part
    while (textIndex < TEXT_BUFFER_LENGTH) {
		// Get last digit, scale x down by 10 (or other base)
        a = x;
        x = floor(x / base);
        a -= base * x;
		// Add last digit to text array (results in reverse order)
        text[textIndex] = int(a) + '0'; textIndex++;
        if (x <= 0.0) break;
    }
    int j = textIndex - 1;  // End of integer part

	// In-place reverse integer digits
    while (i < j) {
        int chr = text[i]; 
		text[i] = text[j];
		text[j] = chr;
		i++; j--;
    }

	text[textIndex] = '.'; textIndex++;

    // Handle fractional part
    while (textIndex < TEXT_BUFFER_LENGTH) {
		// Get first digit, scale y up by 10 (or other base)
        y *= base;
        a = floor(y);
        y -= a;
		// Add first digit to text array
        text[textIndex] = int(a) + '0'; textIndex++;
        if (y <= 0.0) break;
    }

	// Terminante string
    text[textIndex] = 0;
}

void intToDigits(int x) {
    int a;
    const int base = 10;

    // Handle sign
    if (x < 0.0) { 
		text[textIndex] = '-'; textIndex++; x = -x; 
	} else { 
		//text[textIndex] = '+'; textIndex++; 
	}

    // Handle integer part
    int i = textIndex;  // Start of integer part
    while (textIndex < TEXT_BUFFER_LENGTH) {
		// Get last digit, scale x down by 10 (or other base)
        a = x;
        x = x / base;
        a -= base * x;
		// Add last digit to text array (results in reverse order)
        text[textIndex] = a + '0'; textIndex++;
        if (x <= 0) break;
    }
    int j = textIndex - 1;  // End of integer part

	// In-place reverse integer digits
    while (i < j) {
        int chr = text[i]; 
		text[i] = text[j];
		text[j] = chr;
		i++; j--;
    }

	// Terminante string
    text[textIndex] = 0;
}

void printTextAt(float x0, float y0) {
    // Fragment position **in char-units**, relative to x0, y0
    float x = texCoord.x/FXS; x -= x0;
    float y = 0.5*(1.0 - texCoord.y)/FYS; y -= y0;

    // Stop if not inside bbox
    if ((x < 0.0) || (x > float(textIndex)) || (y < 0.0) || (y > 1.0)) return;
    
    int i = int(x); // Char index of this fragment in text
    x -= float(i); // Fraction into this char

	// Grab pixel from correct char texture
    i = text[i];
    x += float(int(i - ((i/16)*16)));
    y += float(int(i/16));
    x /= 16.0; y /= 16.0; // Divide by character-sheet size (in chars)

	vec4 fontPixel = texture2D(FontSampler, vec2(x,y));

    fragColor = vec4(fontPixel.rgb*fontPixel.a + fragColor.rgb*fragColor.a*(1 - fontPixel.a), 1.0);
}

void clearTextBuffer() {
    for (int i = 0; i < TEXT_BUFFER_LENGTH; i++) {
        text[i] = 0;
    }
    textIndex = 0;
}

void c(int character) {
    // Adds character to text buffer, increments index for next character
    // Short name for convenience
    text[textIndex] = character; 
    textIndex++;
}

void drawDebugInfo() {
	// 绘制调试字符
    clearTextBuffer();
    c('T'); c('O'); c('T'); c('A'); c('L'); c(':'); c(' '); floatToDigits(iTime);
    printTextAt(1.0, 1.0);

    int second = int(iTime) % 60;
    int minute = (int(iTime) / 60) % 60;
    int hour = (int(iTime) / 60) / 60;

    clearTextBuffer();
    c('h'); c('r'); c(':'); c(' '); intToDigits(hour);
    printTextAt(1.0, 2.0);

    clearTextBuffer();
    c('m'); c('i'); c('n'); c(':'); c(' '); intToDigits(minute);
    printTextAt(1.0, 3.0);

    clearTextBuffer();
    c('s'); c('e'); c('c'); c(':'); c(' '); intToDigits(second);
    printTextAt(1.0, 4.0);

}

//==========================================================================================
// 调试信息结束
//==========================================================================================

// 两位256（罗马数字CCLVI）进制数转10进制
float CCLVIToDec(float X, float Y) {
    return X + Y*256.0;
}

// 从颜色浮点数获取记录的数字（理应是0到255的正整数）
float getCounting(float x) {
    return x * 255.0;
}

void main()
{
    // 详见update_time.fsh
    vec4 timeInfo = texture(TimeSampler, texCoord);
    // X=(1.0-x)*255.0算出每位的值
    // 然后进行256进制的换算，X*256^0+Y*256^1+Z*256^3
    iTime = CCLVIToDec(getCounting(timeInfo.x), getCounting(timeInfo.y));
    // 加上小数位
    iTime += Time;

    fragColor = vec4( texture( DiffuseSampler, texCoord ).rgb, 1.0);

	drawDebugInfo();

}