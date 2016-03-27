module iode.parsing.parser;

import std.stdio;
import std.conv;
import iode.lexical.lexer;
import iode.lexical.token;
import iode.ast.node;
import iode.gen.stash;
import iode.errors.parserError;

/* Converts tokens into AST */
class Parser {
    private Lexer lexer;
    public int pos;
    public ulong totalTokens;

    this(Lexer lexer) {
        this.lexer = lexer;
        this.pos = 0;
        Stash.line = 1;
        this.totalTokens = lexer.tokens.length;
    }

    /* checks up on the next token */
    public Token peekToken() {
        return lexer.peekToken();
    }

    /* checks if the next token is a certain type */
    public bool peekCheck(TokenType type) {
        return lexer.peekToken().getType == type;
    }

    /* checks if a specific token is a certain type */
    public bool peekSpecificCheck(TokenType type, int i) {
        return lexer.peekSpecific(i).getType() == type;
    }

    /* checks up on a specific token */
    public Token peekSpecific(int i) {
        return lexer.peekSpecific(i);
    }

    /* gets the next token */
    public Token nextToken() {
        pos++;

        if (peekCheck(TokenType.NEWLINE)) {
            Stash.line++;
        }

        return lexer.nextToken();
    }

    /* gets the next token and skips newlines */
    public Token nextToken(bool skip) {
        if (skip) {
            return nextToken();
        } else {
            Token t = nextToken();
            skipNewline();
            return t;
        }
    }

    /* skips newlines */
    public void skipNewline() {
        if (!(totalTokens >= pos)) {
            while (peekCheck(TokenType.NEWLINE) || peekCheck(TokenType.SEMICOLON)) {
                nextToken();
            }
        }
    }

    /* checks if the next token is a terminator */
    public bool terminator() {
        return peekCheck(TokenType.NEWLINE) || peekCheck(TokenType.SEMICOLON);
    }

    /* parses numbers */
    public Node parseNumber() {
        ulong converted = to!ulong(nextToken().getValue());
        Node left = new NodeNumber(converted);
        string op = null;
        Node right = null;

        while (peekCheck(TokenType.ADD) || peekCheck(TokenType.SUB)
            || peekCheck(TokenType.MUL) || peekCheck(TokenType.DIV)) {
            skipNewline();
            op = this.nextToken().getValue();
            skipNewline();

            if (peekCheck(TokenType.NUMBER)) {
                right = cast(NodeNumber)this.parseNumber();
            } else if (peekCheck(TokenType.DOUBLE)) {
                right = cast(NodeDouble)this.parseDouble();
            } else if (peekCheck(TokenType.IDENT)) {
                right = new NodeVariable(nextToken().getValue());
            } else {
                throw new ParserException("Expected a number, double, or variable after binary operation");
            }
        }

        if (op != null) {
            left = new NodeBinaryOp(left, op, right);
        }

        return left;
    }

    /* parses doubles */
    public Node parseDouble() {
        double converted = to!double(nextToken().getValue());
        Node left = new NodeDouble(converted);
        string op = null;
        Node right = null;

        while (peekCheck(TokenType.ADD) || peekCheck(TokenType.SUB)
            || peekCheck(TokenType.MUL) || peekCheck(TokenType.DIV)) {
            skipNewline();
            op = this.nextToken().getValue();
            skipNewline();

            if (peekCheck(TokenType.NUMBER)) {
                right = cast(NodeNumber)this.parseNumber();
            } else if (peekCheck(TokenType.DOUBLE)) {
                right = cast(NodeDouble)this.parseDouble();
            } else if (peekCheck(TokenType.IDENT)) {
                right = new NodeVariable(nextToken().getValue());
            } else {
                throw new ParserException("Expected a number, double, or variable after binary operation");
            }
        }

        if (op != null) {
            left = new NodeBinaryOp(left, op, right);
        }

        return left;
    }

    /* parses strings */
    public Node parseString() {
        return new NodeString(nextToken().getValue());
    }

    /* parses boolean */
    public Node parseBoolean() {
        return new NodeNumber(to!bool(nextToken().getValue()));
    }

    /* parses null */
    public Node parseNull() {
        nextToken();
        return new NodeNull();
    }

    /* parses variable declaration */
    public Node parseDeclaration(bool constant) {
        nextToken(true);

        if (peekCheck(TokenType.IDENT)) {
            string name = nextToken(true).getValue();

            if (peekCheck(TokenType.EQUALS)) {
                nextToken(true);

                Node next = literal();

                if (terminator()) {
                    nextToken(true);

                    return new NodeDeclaration(constant, name, next);
                } else {
                    throw new ParserException("Expected a newline");
                }
            } else if (peekCheck(TokenType.COLON)) {
                nextToken(true);

                if (peekCheck(TokenType.IDENT)) {
                    string type = nextToken(true).getValue();

                    if (peekCheck(TokenType.EQUALS)) {
                        nextToken(true);

                        Node next = literal();

                        if (terminator()) {
                            nextToken(true);

                            return new NodeTypedDeclaration(constant, name, type, next);
                        } else {
                            throw new ParserException("Expected a newline");
                        }
                    } else {
                        throw new ParserException("Expected '=' or ':'");
                    }
                } else {
                    throw new ParserException("Expected a type");
                }
            } else {
                throw new ParserException("Expected '=' or ':'");
            }
        } else {
            throw new ParserException("Expected an identifier");
        }
    }

    /* parses an ident as a literal */
    public Node parseIdentLiteral() {
        string ident = nextToken().getValue();

        if (peekCheck(TokenType.LPAREN)) {
            nextToken(true);
            Node[] args;

            while (!peekCheck(TokenType.RPAREN)) {
                args ~= literal();

                if (!peekCheck(TokenType.COMMA) && !peekCheck(TokenType.RPAREN)) {
                    throw new ParserException("Expected ',' or ')'");
                }

                if (peekCheck(TokenType.COMMA)) {
                    nextToken(true);
                } else if (peekCheck(TokenType.RPAREN)) {
                    break;
                }
            }

            if (peekCheck(TokenType.RPAREN)) {
                nextToken();

                return new NodeCall(ident, args);
            } else {
                throw new ParserException("Expected ',' or ')'");
            }
        } else {
            Node left = new NodeVariable(ident);
            string op = null;
            Node right = null;

            while (peekCheck(TokenType.ADD) || peekCheck(TokenType.SUB)
                || peekCheck(TokenType.MUL) || peekCheck(TokenType.DIV)) {
                skipNewline();
                op = this.nextToken().getValue();
                skipNewline();

                if (peekCheck(TokenType.NUMBER)) {
                    right = cast(NodeNumber)this.parseNumber();
                } else if (peekCheck(TokenType.DOUBLE)) {
                    right = cast(NodeDouble)this.parseDouble();
                } else if (peekCheck(TokenType.IDENT)) {
                    right = new NodeVariable(nextToken().getValue());
                } else {
                    throw new ParserException("Expected a number, double, or variable after binary operation");
                }
            }

            if (op != null) {
                left = new NodeBinaryOp(left, op, right);
            }

            return left;
        }
    }

    /* parses an ident as an expression */
    public Node parseIdent() {
        string ident = nextToken(true).getValue();

        if (peekCheck(TokenType.LPAREN)) {
            nextToken(true);
            Node[] args;

            while (!peekCheck(TokenType.RPAREN)) {
                args ~= literal();

                if (!peekCheck(TokenType.COMMA) && !peekCheck(TokenType.RPAREN)) {
                    throw new ParserException("Expected ',' or ')'");
                }

                if (peekCheck(TokenType.COMMA)) {
                    nextToken(true);
                } else if (peekCheck(TokenType.RPAREN)) {
                    break;
                }
            }

            if (peekCheck(TokenType.RPAREN)) {
                nextToken();

                if (terminator()) {
                    nextToken(true);

                    return new NodeCall(ident, args);
                } else {
                    throw new ParserException("Expected a newline");
                }
            } else {
                throw new ParserException("Expected ',' or ')'");
            }
        } else if (peekCheck(TokenType.EQUALS)) {
            nextToken(true);

            Node next = literal();

            if (terminator()) {
                nextToken(true);

                return new NodeSetting(ident, next);
            } else {
                throw new ParserException("Expected a newline");
            }
        } else {
            throw new ParserException("Expected nothing, '(', or '=' after identifier");
        }
    }

    /* parses a function declaration */
    public Node parseFunction() {
        nextToken(true);

        if (peekCheck(TokenType.IDENT)) {
            string name = nextToken(true).getValue();

            if (peekCheck(TokenType.LPAREN)) {
                nextToken(true);
                Arg[] args;

                while (!peekCheck(TokenType.RPAREN)) {
                    if (peekCheck(TokenType.IDENT)) {
                        string argName = nextToken(true).getValue();

                        if (peekCheck(TokenType.COLON)) {
                            nextToken(true);

                            if (peekCheck(TokenType.IDENT)) {
                                string type = nextToken(true).getValue();

                                args ~= new Arg(type, argName);

                                if (peekCheck(TokenType.COMMA)) {
                                    nextToken(true);
                                } else if (peekCheck(TokenType.RPAREN)) {
                                    break;
                                } else {
                                    throw new ParserException("Expected ',' or ')'");
                                }
                            } else {
                                throw new ParserException("Expected a type after ':'");
                            }
                        } else {
                            throw new ParserException("Expected ':' after parameter name");
                        }
                    } else {
                        throw new ParserException("Expected an identifier");
                    }
                }

                Node[] block;

                if (peekCheck(TokenType.RPAREN)) {
                    nextToken(true);

                    if (peekCheck(TokenType.GT)) {
                        nextToken(true);

                        if (peekCheck(TokenType.IDENT)) {
                            string type = nextToken().getValue();

                            if (peekCheck(TokenType.LBRACE)) {
                                nextToken(true);

                                while (!peekCheck(TokenType.RBRACE)) {
                                    block ~= start();
                                    skipNewline();
                                }

                                nextToken(true);

                                return new NodeFunction(name, args, type, block);
                            } else {
                                throw new ParserException("Expected '{'");
                            }
                        } else {
                            throw new ParserException("Expected type");
                        }
                    } else {
                        throw new ParserException("Expected '>'");
                    }
                } else {
                    throw new ParserException("Expected ')'");
                }
            } else {
                throw new ParserException("Expected '('");
            }
        } else {
            throw new ParserException("Expected a function name");
        }
    }

    /* parses a return */
    public Node parseReturn() {
        nextToken(true);
        Node lit = literal();

        if (terminator()) {
            nextToken(true);
        } else {
            throw new ParserException("Expected a newline");
        }

        return new NodeReturn(lit);
    }

    /* parses a newline */
    public Node parseNewline() {
        nextToken();
        Stash.line++;
        return new NodeNewline();
    }

    /* gets the next literal */
    public Node literal() {
        TokenType t = peekToken().getType();

        switch (t) {
            default:
                throw new ParserException("Unexpected token '" ~ t ~ "'");
            case TokenType.NUMBER:
                return parseNumber();
            case TokenType.DOUBLE:
                return parseDouble();
            case TokenType.BOOL:
                return parseBoolean();
            case TokenType.IDENT:
                return parseIdentLiteral();
            case TokenType.STRING:
                return parseString();
            case TokenType.NULL:
                return parseNull();
        }
    }

    /* gets the next statement */
    public Node start() {
        TokenType t = peekToken().getType();

        switch (t) {
            default:
                throw new ParserException("Unexpected token '" ~ t ~ "'");
            case TokenType.VAR:
                return parseDeclaration(false);
            case TokenType.LET:
                return parseDeclaration(true);
            case TokenType.FN:
                return parseFunction();
            case TokenType.IDENT:
                return parseIdent();
            case TokenType.RETURN:
                return parseReturn();
            case TokenType.NEWLINE:
                return parseNewline();
        }
    }
}
