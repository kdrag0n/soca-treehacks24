from openai import OpenAI
import cv2
import base64

IMAGE_SIZE = 512
GRID_SIZE = 32
COLOR = (255, 255, 0)
FONT_SCALE = 1.0

SAMPLES_PATH = "./images/examples/{}.jpeg"
# todo: DSPy?

def text(text: str):
    return { 'type': 'text', 'text': text }
def image(norm_img):
    b64_image = base64.b64encode(cv2.imencode('.jpg', img)[1]).decode()
    return { 'type': 'image_url', 'image_url': { 'url': f"data:image/jpeg;base64,{b64_image}"}}

def make_sys_prompt():
    sample_img = annotate_image(cv2.imread(SAMPLES_PATH.format('desk')))

    return [ {'role': 'system', 'content': [
        text("""
Help the user find something in the image. If it cannot be found, suggest some possible places to go to look for it.
The image is partitioned into cells. You must output the label of the cell that contains the object.
Follow these steps:
1. Where in the image is the object?
2. What is the label of one of the cells containing the object?

You must follow these examples:
"""),
        text("EXAMPLE INPUT:\nWhere is my water bottle?"),
        image(sample_img),
        text("EXAMPLE OUTPUT:\n1. The object is in top center of the image.\n2. E8"),
        text("EXAMPLE INPUT:\nWhere is my pencil?"),
        image(sample_img),
        text("EXAMPLE OUTPUT:\nThe object is in the center left of the image.\n2. J1")
    ] } ]

def annotate_image(img):
    # normalize the image
    img = cv2.resize(img, (IMAGE_SIZE, IMAGE_SIZE), interpolation=cv2.INTER_AREA)
    for i in range(IMAGE_SIZE//GRID_SIZE):
        cv2.line(img, (0, i*GRID_SIZE), (IMAGE_SIZE, i*GRID_SIZE), COLOR)
        cv2.line(img, (i*GRID_SIZE, 0), (i*GRID_SIZE, IMAGE_SIZE), COLOR)
        # cv2.putText(img, f"{i}", (int(FONT_SCALE*13), (i+1)*GRID_SIZE - 2), cv2.FONT_HERSHEY_PLAIN, 1.0, COLOR)
        # cv2.putText(img, f"{chr(65 + j)}", (j*GRID_SIZE+2, GRID_SIZE-2), cv2.FONT_HERSHEY_PLAIN, 1.0, COLOR)

        for j in range(IMAGE_SIZE//GRID_SIZE):
            cv2.putText(img, f"{chr(65 + j)}", (i*GRID_SIZE+1, (j+1)*GRID_SIZE-2), cv2.FONT_HERSHEY_PLAIN, 1.0, COLOR)
            cv2.putText(img, f"{i}", (i * GRID_SIZE + int(FONT_SCALE*11), (j+1)*GRID_SIZE - 2), cv2.FONT_HERSHEY_PLAIN, 1.0, COLOR)

    cv2.imshow('annotated', img)
    cv2.waitKey(0)

    return img

def make_user_prompt(query: str, img):
    img = annotate_image(img)

    # make messages
    return [
        { 'role': 'user', 'content': [
            text(query),
            image(img)
         ] }
    ]



IMG_FILE = "./images/IMG_2867 Large.jpeg"; QUESTION = "where is the door handle"
# IMG_FILE = "./images/IMG_2867 Large.jpeg"; QUESTION = "where is my blue jacket"
# IMG_FILE = "./images/examples/desk.jpeg"; QUESTION = "Where is my water bottle"
img = cv2.imread(IMG_FILE)

sys_msg = make_sys_prompt()
user_msg = make_user_prompt(QUESTION, img)

client = OpenAI()

response = client.chat.completions.create(
  model="gpt-4-vision-preview",
  messages=[ *sys_msg, *user_msg ],
  max_tokens=30,
  temperature=0,
  n=1
)

print(response.choices[0])