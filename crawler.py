#!/usr/bin/env python
# -*- coding: utf-8 -*-

import urllib2
from urlparse import urljoin
from BeautifulSoup import BeautifulSoup
import sys, os

URL_BASE = "http://uva.onlinejudge.org/external"
URL_FORMAT = URL_BASE + "/%s/%s.html"

target_url = ""

def build_url(question_num_str):
    # the first %d means question volumn number, 
    # and the second means question number
    global target_url
    volumn_num_str = question_num_str[:(len(question_num_str) - 2)]
    target_url = URL_FORMAT % (volumn_num_str, question_num_str)
    
def get_soup_from_url(url):
    request = urllib2.Request(url, headers={'User-Agent':'Magic Browser'})
    response = urllib2.urlopen(request)
    return BeautifulSoup(response.read())

def get_latex_from_url(url):
    request = urllib2.Request(url, headers={'User-Agent':'Magic Browser'})
    response = urllib2.urlopen(request)
    parser = Html2Latex()
    return parser.parse_html(response.read())

def get_title_from_soup(soup, question_num_str):
    title_raw = soup.title.string
    index = title_raw.find(':')
    if index != -1:
        title_raw = title_raw[index + 2:]
    else:
        index = title_raw.find('-')
        if index != -1:
            title_raw = title_raw[index + 2:]
    title_cleaned = "%s_%s" % (question_num_str, title_raw.strip().lower().replace(' ', '_'))
    return title_cleaned

def get_question_name(question_num_str, acm_root):
    # print clause is for shell variable setting
    # if the folder is existed
    for name in os.listdir(acm_root):
        if name.startswith("%s_" % question_num_str):
            return name
        
    # or else, should fetch from network
    build_url(question_num_str)
    soup = get_soup_from_url(target_url)
    return get_title_from_soup(soup, question_num_str)
    
def get_input_data(soup):
    try:
        input_raw = soup.findAll("pre")[-2].string
        input_clean = input_raw.strip()
    except IndexError:
        input_clean = ""
    return input_clean

def get_output_data(soup):
    try:
        output_raw = soup.findAll("pre")[-1].string
        output_clean = output_raw.lstrip()
    except AttributeError:
        output_clean = ""
    return output_clean

def download_img(soup, path):
    img_names = [node["src"] for node in soup.findAll("img")]
    
    for img_name in img_names:
        img_url = urljoin(target_url, img_name)
        data = urllib2.urlopen(img_url).read()
        img_path = "%s/%s" % (path, img_name)

        f = open(img_path,'wb')   
        f.write(data)   
        f.close() 

def write_to_file(content, path):
    f = open(path, 'w')    
    try:
        f.write(content)
    except Exception:
        print("write file %s error." % path)
        sys.exit(1);
    finally:
        f.close()

def parse(soup, question_num_str):
    html_data = str(soup)    
    title = get_title_from_soup(soup, question_num_str)
    input_data = get_input_data(soup)
    output_data = get_output_data(soup)
    return html_data, title, input_data, output_data

def do_craw(question_num_str, acm_root):
    build_url(question_num_str)
    soup = get_soup_from_url(target_url)
    html_data, title, input_data, output_data = parse(soup, question_num_str)

    # create question root directory
    question_root = "%s/%s" % (acm_root, title)
    if not os.path.exists(question_root):
        os.mkdir(question_root)

        ####################
        # save data to file
        ####################
    
        # build files path
        html_path = "%s/%s.html" % (question_root, title)
        input_path = "%s/test_%s.txt" % (question_root, title)
        output_path = "%s/expect_%s.txt" % (question_root, title)
        src_path = "%s/%s.c" % (question_root, title)
        
        # write files
        # html
        write_to_file(html_data, html_path)
        # img
        download_img(soup, question_root)
        # input
        write_to_file(input_data, input_path)
        # output
        write_to_file(output_data, output_path)
        # c source code
        src_content = """#include <stdio.h>
#include <string.h>
#include <stdlib.h>

int main(int argc, char *args[]) {

    return 0;
}
"""
        write_to_file(src_content, src_path)
        print 1
    else:
        print 0
        

if __name__ == '__main__':
    """
    root = "/Users/ad-in/Desktop"
    for i in range(101, 102):
        do_craw(str(i), root)
    """
    
    if sys.argv[1] == "q":
        question_num_str, acm_root = sys.argv[2], sys.argv[3]        
        print get_question_name(question_num_str, acm_root)
    else:   
        question_num_str, acm_root = sys.argv[1], sys.argv[2]
        do_craw(question_num_str, acm_root)
    
